;; Small Business Incubation Contract
;; Provides resources and support for new business development

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BUSINESS-EXISTS (err u101))
(define-constant ERR-BUSINESS-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STAGE (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-INPUT (err u105))

;; Data Variables
(define-data-var total-businesses uint u0)
(define-data-var total-funding-allocated uint u0)

;; Data Maps
(define-map businesses
  { business-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    stage: uint, ;; 1=idea, 2=development, 3=launch, 4=growth, 5=mature
    funding-requested: uint,
    funding-received: uint,
    employees: uint,
    revenue: uint,
    created-at: uint,
    last-updated: uint,
    active: bool
  }
)

(define-map business-milestones
  { business-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    target-date: uint,
    completed: bool,
    completed-date: (optional uint),
    reward-amount: uint
  }
)

(define-map funding-rounds
  { business-id: uint, round-id: uint }
  {
    amount: uint,
    funded-date: uint,
    conditions: (string-ascii 300),
    repayment-terms: (string-ascii 200)
  }
)

;; Authorization check
(define-private (is-authorized (caller principal))
  (is-eq caller CONTRACT-OWNER)
)

;; Register a new business for incubation
(define-public (register-business
  (name (string-ascii 100))
  (description (string-ascii 500))
  (funding-requested uint)
  (initial-employees uint))
  (let
    (
      (business-id (+ (var-get total-businesses) u1))
      (current-block block-height)
    )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> funding-requested u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? businesses { business-id: business-id })) ERR-BUSINESS-EXISTS)

    (map-set businesses
      { business-id: business-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        stage: u1,
        funding-requested: funding-requested,
        funding-received: u0,
        employees: initial-employees,
        revenue: u0,
        created-at: current-block,
        last-updated: current-block,
        active: true
      }
    )

    (var-set total-businesses business-id)
    (ok business-id)
  )
)

;; Update business stage
(define-public (update-business-stage (business-id uint) (new-stage uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
      (current-block block-height)
    )
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-stage u1) (<= new-stage u5)) ERR-INVALID-STAGE)
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)

    (map-set businesses
      { business-id: business-id }
      (merge business {
        stage: new-stage,
        last-updated: current-block
      })
    )
    (ok true)
  )
)

;; Add milestone for business
(define-public (add-milestone
  (business-id uint)
  (milestone-id uint)
  (description (string-ascii 200))
  (target-date uint)
  (reward-amount uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> target-date block-height) ERR-INVALID-INPUT)

    (map-set business-milestones
      { business-id: business-id, milestone-id: milestone-id }
      {
        description: description,
        target-date: target-date,
        completed: false,
        completed-date: none,
        reward-amount: reward-amount
      }
    )
    (ok true)
  )
)

;; Complete milestone
(define-public (complete-milestone (business-id uint) (milestone-id uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
      (milestone (unwrap! (map-get? business-milestones { business-id: business-id, milestone-id: milestone-id }) ERR-BUSINESS-NOT-FOUND))
      (current-block block-height)
    )
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed milestone)) ERR-INVALID-INPUT)

    (map-set business-milestones
      { business-id: business-id, milestone-id: milestone-id }
      (merge milestone {
        completed: true,
        completed-date: (some current-block)
      })
    )
    (ok true)
  )
)

;; Provide funding to business
(define-public (provide-funding
  (business-id uint)
  (round-id uint)
  (amount uint)
  (conditions (string-ascii 300))
  (repayment-terms (string-ascii 200)))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
      (current-block block-height)
      (new-funding-received (+ (get funding-received business) amount))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (<= new-funding-received (get funding-requested business)) ERR-INVALID-INPUT)

    (map-set funding-rounds
      { business-id: business-id, round-id: round-id }
      {
        amount: amount,
        funded-date: current-block,
        conditions: conditions,
        repayment-terms: repayment-terms
      }
    )

    (map-set businesses
      { business-id: business-id }
      (merge business {
        funding-received: new-funding-received,
        last-updated: current-block
      })
    )

    (var-set total-funding-allocated (+ (var-get total-funding-allocated) amount))
    (ok true)
  )
)

;; Update business metrics
(define-public (update-business-metrics
  (business-id uint)
  (new-employees uint)
  (new-revenue uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) ERR-BUSINESS-NOT-FOUND))
      (current-block block-height)
    )
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-AUTHORIZED)
    (asserts! (get active business) ERR-BUSINESS-NOT-FOUND)

    (map-set businesses
      { business-id: business-id }
      (merge business {
        employees: new-employees,
        revenue: new-revenue,
        last-updated: current-block
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

(define-read-only (get-milestone (business-id uint) (milestone-id uint))
  (map-get? business-milestones { business-id: business-id, milestone-id: milestone-id })
)

(define-read-only (get-funding-round (business-id uint) (round-id uint))
  (map-get? funding-rounds { business-id: business-id, round-id: round-id })
)

(define-read-only (get-total-businesses)
  (var-get total-businesses)
)

(define-read-only (get-total-funding-allocated)
  (var-get total-funding-allocated)
)
