;; Astronomical Data Submission Contract
;; Initial implementation with core functionality for astronomical data collaboration

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-data (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-invalid-input (err u104))

;; Data submission token requirement
(define-constant minimum-tokens u500)
(define-constant max-observation-length u256)

;; Astronomical observation structure
(define-map celestial-observations 
  { 
    celestial-id: uint, 
    observation-epoch: uint 
  }
  {
    observation-data: (string-utf8 256),
    astronomer: principal,
    tokens: uint
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
        tokens: minimum-tokens
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
    )
    
    ;; Validate inputs
    (asserts! (is-valid-celestial-id celestial-id) err-invalid-input)
    (asserts! (is-valid-observation observation-data) err-invalid-input)
    
    ;; Require minimum tokens
    (asserts! (> (stx-get-balance tx-sender) minimum-tokens) err-insufficient-tokens)
    
    ;; Store observation data
    (map-set celestial-observations 
      { celestial-id: celestial-id, observation-epoch: current-epoch }
      {
        observation-data: observation-data,
        astronomer: tx-sender,
        tokens: minimum-tokens
      }
    )
    
    ;; Lock astronomer's tokens
    (try! (stx-transfer? minimum-tokens tx-sender (as-contract tx-sender)))
    
    (ok true)
  )
)

;; Admin function to return tokens to an astronomer
(define-public (return-tokens
  (celestial-id uint)
  (observation-epoch uint)
)
  (let 
    (
      (observation-entry 
        (unwrap! 
          (map-get? celestial-observations 
            { celestial-id: celestial-id, observation-epoch: observation-epoch }
          )
          err-invalid-data
        )
      )
    )
    
    ;; Only contract owner can return tokens
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    
    ;; Return the astronomer's tokens
    (try! 
      (as-contract 
        (stx-transfer? 
          (get tokens observation-entry)
          tx-sender 
          (get astronomer observation-entry)
        )
      )
    )
    
    (ok true)
  )
)

;; Read-only function to get observation data
(define-read-only (get-observation (celestial-id uint) (observation-epoch uint))
  (map-get? celestial-observations { celestial-id: celestial-id, observation-epoch: observation-epoch })
)