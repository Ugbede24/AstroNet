;; Astronomical Data Submission with Peer Review
;; Added peer review system and data cataloging functionality

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-data (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-already-cataloged (err u103))
(define-constant err-invalid-input (err u104))

;; Data submission token requirement
(define-constant minimum-tokens u500)
(define-constant max-observation-length u256)

;; Grant fund for astronomical contributors
(define-data-var grant-fund uint u10000)

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
    )
    
    ;; Validate inputs
    (asserts! (is-valid-celestial-id celestial-id) err-invalid-input)
    (asserts! (> observation-epoch u0) err-invalid-input)
    
    ;; Prevent self-review
    (asserts! 
      (not (is-eq tx-sender (get astronomer observation-entry))) 
      err-unauthorized
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
        
        ;; Return tokens to astronomer
        (try! 
          (as-contract 
            (stx-transfer? 
              minimum-tokens
              tx-sender 
              (get astronomer observation-entry)
            )
          )
        )
      )
      true
    )
    
    (ok true)
  )
)

;; Admin function to add to grant fund
(define-public (contribute-to-grant-fund (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> amount u0) err-invalid-input)
    
    (var-set grant-fund (+ (var-get grant-fund) amount))
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