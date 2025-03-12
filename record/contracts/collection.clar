;; Complete Astronomical Data Collaboration Network
;; Final implementation with incentive mechanisms and comprehensive data validation

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-data (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-already-cataloged (err u103))
(define-constant err-invalid-input (err u104))
(define-constant err-already-reviewed (err u105))

;; Data submission token requirement
(define-constant minimum-tokens u500)
(define-constant max-observation-length u256)
(define-constant max-grant-fund u1000000)

;; Grant fund for astronomical contributors
(define-data-var grant-fund uint u10000)

;; Reviewer reputation tracking
(define-map reviewer-reputation
  { reviewer: principal }
  { reputation-score: uint }
)

;; Astronomical observation structure
(define-map celestial-observations 
  { 
    celestial-id: uint, 
    observation-epoch: uint 
  }
  {
    observation-data: (string-utf8 256),
    astronomer: principal,
    tokens: uint,
    cataloged: bool
  }
)

;; Peer review tracking
(define-map observation-reviews
  {
    celestial-id: uint,
    observation-epoch: uint
  }
  {
    review-count: uint,
    cataloged: bool
  }
)

;; Track individual reviewer decisions
(define-map review-decisions
  {
    celestial-id: uint,
    observation-epoch: uint,
    reviewer: principal
  }
  {
    reviewed: bool,
    decision: bool
  }
)

;; Input validation functions
(define-private (is-valid-celestial-id (celestial-id uint))
  (and (> celestial-id u0) (<= celestial-id u10000))
)

(define-private (is-valid-observation (observation-data (string-utf8 256)))
  (and 
    (> (len observation-data) u0) 
    (<= (len observation-data) max-observation-length)
  )
)

;; Helper function to get or initialize reviewer reputation
(define-private (get-reputation (reviewer principal))
  (default-to 
    { reputation-score: u10 } 
    (map-get? reviewer-reputation { reviewer: reviewer })
  )
)

;; Update reviewer reputation
(define-private (update-reputation (reviewer principal) (is-consensus bool))
  (let 
    (
      (current-reputation (get reputation-score (get-reputation reviewer)))
      (new-score (if is-consensus 
                  (+ current-reputation u1) 
                  (if (> current-reputation u1) (- current-reputation u1) u1)))
    )
    
    (map-set reviewer-reputation 
      { reviewer: reviewer }
      { reputation-score: new-score }
    )
  )
)

;; Register a new celestial body observation
(define-public (register-celestial-body 
  (celestial-id uint)
  (initial-observation (string-utf8 256))
)
  (begin
    ;; Validate inputs
    (asserts! (is-valid-celestial-id celestial-id) err-invalid-input)
    (asserts! (is-valid-observation initial-observation) err-invalid-input)
    
    ;; Check tokens
    (asserts! (> (stx-get-balance tx-sender) minimum-tokens) err-insufficient-tokens)
    
    ;; Store initial observation data
    (map-set celestial-observations 
      { celestial-id: celestial-id, observation-epoch: block-height }
      {
        observation-data: initial-observation,
        astronomer: tx-sender,
        tokens: minimum-tokens,
        cataloged: false
      }
    )
    
    ;; Initialize review tracking
    (map-set observation-reviews
      { celestial-id: celestial-id, observation-epoch: block-height }
      {
        review-count: u0,
        cataloged: false
      }
    )
    
    ;; Lock astronomer's tokens
    (try! (stx-transfer? minimum-tokens tx-sender (as-contract tx-sender)))
    
    (ok true)
  )
)

;; Submit astronomical observation data
(define-public (submit-observation-data
  (celestial-id uint)
  (observation-data (string-utf8 256))
)
  (let 
    (
      (current-epoch block-height)
      (existing-entry 
        (map-get? celestial-observations 
          { celestial-id: celestial-id, observation-epoch: current-epoch }
        )
    ))
    
    ;; Validate inputs
    (asserts! (is-valid-celestial-id celestial-id) err-invalid-input)
    (asserts! (is-valid-observation observation-data) err-invalid-input)
    
    ;; Prevent duplicate submissions
    (asserts! (is-none existing-entry) err-already-cataloged)
    
    ;; Require minimum tokens
    (asserts! (> (stx-get-balance tx-sender) minimum-tokens) err-insufficient-tokens)
    
    ;; Store observation data
    (map-set celestial-observations 
      { celestial-id: celestial-id, observation-epoch: current-epoch }
      {
        observation-data: observation-data,
        astronomer: tx-sender,
        tokens: minimum-tokens,
        cataloged: false
      }
    )
    
    ;; Initialize review tracking
    (map-set observation-reviews
      { celestial-id: celestial-id, observation-epoch: current-epoch }
      {
        review-count: u0,
        cataloged: false
      }
    )
    
    ;; Lock astronomer's tokens
    (try! (stx-transfer? minimum-tokens tx-sender (as-contract tx-sender)))
    
    (ok true)
  )
)

;; Peer review of submitted astronomical data
(define-public (peer-review-observation
  (celestial-id uint)
  (observation-epoch uint)
  (is-accurate bool)
)
  (let 
    (
      (review-entry 
        (unwrap! 
          (map-get? observation-reviews 
            { celestial-id: celestial-id, observation-epoch: observation-epoch }
          )
          err-invalid-data
        )
      )
      (observation-entry 
        (unwrap! 
          (map-get? celestial-observations 
            { celestial-id: celestial-id, observation-epoch: observation-epoch }
          )
          err-invalid-data
        )
      )
      (previous-review 
        (map-get? review-decisions
          {
            celestial-id: celestial-id,
            observation-epoch: observation-epoch,
            reviewer: tx-sender
          }
        )
      )
    )
    
    ;; Validate inputs
    (asserts! (is-valid-celestial-id celestial-id) err-invalid-input)
    (asserts! (> observation-epoch u0) err-invalid-input)
    
    ;; Prevent self-review
    (asserts! 
      (not (is-eq tx-sender (get astronomer observation-entry))) 
      err-unauthorized
    )
    
    ;; Prevent multiple reviews from same reviewer
    (asserts! (is-none previous-review) err-already-reviewed)
    
    ;; Record this review decision
    (map-set review-decisions
      {
        celestial-id: celestial-id,
        observation-epoch: observation-epoch,
        reviewer: tx-sender
      }
      {
        reviewed: true,
        decision: is-accurate
      }
    )
    
    ;; Update review count
    (map-set observation-reviews
      { celestial-id: celestial-id, observation-epoch: observation-epoch }
      {
        review-count: (+ (get review-count review-entry) u1),
        cataloged: (if is-accurate 
                    (>= (+ (get review-count review-entry) u1) u3)
                    false)
      }
    )
    
    ;; If data is validated with 3 positive reviews, update as cataloged
    (if 
      (and is-accurate (>= (+ (get review-count review-entry) u1) u3))
      (begin
        ;; Update observation as cataloged
        (map-set celestial-observations 
          { celestial-id: celestial-id, observation-epoch: observation-epoch }
          (merge observation-entry { cataloged: true })
        )
        
        ;; Distribute grant and return tokens
        (try! 
          (as-contract 
            (stx-transfer? 
              (+ minimum-tokens (/ (var-get grant-fund) u10)) 
              tx-sender 
              (get astronomer observation-entry)
            )
          )
        )
        
        ;; Update reviewer reputation (positive for consensus with final decision)
        (update-reputation tx-sender true)
      )
      ;; If inaccurate, penalize contributor
      (if (not is-accurate)
        (begin
          (try! 
            (as-contract 
              (stx-transfer? 
                (/ minimum-tokens u2) 
                tx-sender 
                contract-owner
              )
            )
          )
          
          ;; Update reviewer reputation (negative if not aligned with final decision)
          (update-reputation tx-sender false)
          
          true
        )
        true
      )
    )
    
    (ok true)
  )
)

;; Admin function to add to grant fund
(define-public (contribute-to-grant-fund (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (and (> amount u0) (<= amount max-grant-fund)) err-invalid-input)
    
    (var-set grant-fund (+ (var-get grant-fund) amount))
    (ok true)
  )
)

;; Feature for high-reputation astronomers to claim extra tokens
(define-public (claim-reputation-bonus)
  (let 
    (
      (reputation-entry (get-reputation tx-sender))
      (reputation-score (get reputation-score reputation-entry))
      (bonus-amount (if (>= reputation-score u50) u1000 u0))
    )
    
    ;; Check if reputation is high enough
    (asserts! (>= reputation-score u50) err-unauthorized)
    
    ;; Check if grant fund has enough tokens
    (asserts! (>= (var-get grant-fund) bonus-amount) err-insufficient-tokens)
    
    ;; Transfer bonus to reviewer
    (try! 
      (as-contract
        (stx-transfer? bonus-amount tx-sender tx-sender)
      )
    )
    
    ;; Update grant fund
    (var-set grant-fund (- (var-get grant-fund) bonus-amount))
    
    (ok true)
  )
)

;; Read-only function to check observation catalog status
(define-read-only (is-observation-cataloged (celestial-id uint) (observation-epoch uint))
  (match 
    (map-get? observation-reviews { celestial-id: celestial-id, observation-epoch: observation-epoch })
    entry (get cataloged entry)
    false
  )
)

;; Read-only function to get observation data
(define-read-only (get-observation (celestial-id uint) (observation-epoch uint))
  (map-get? celestial-observations { celestial-id: celestial-id, observation-epoch: observation-epoch })
)

;; Read-only function to get reviewer reputation
(define-read-only (get-reviewer-reputation (reviewer principal))
  (get-reputation reviewer)
)

;; Read-only function to get grant fund balance
(define-read-only (get-grant-fund-balance)
  (var-get grant-fund)
)