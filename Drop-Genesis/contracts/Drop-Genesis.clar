;; Drop Genesis - Merit-based Token Distribution with Sybil Resistance
;; Built on Stacks blockchain using Clarity

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_CLAIMED (err u101))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u102))
(define-constant ERR_DISTRIBUTION_NOT_ACTIVE (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_USER_NOT_FOUND (err u105))
(define-constant ERR_COOLDOWN_ACTIVE (err u106))

;; Minimum reputation required for token claims
(define-constant MIN_REPUTATION_FOR_CLAIM u100)
(define-constant REPUTATION_DECAY_RATE u1)
(define-constant COOLDOWN_PERIOD u144) ;; ~24 hours in blocks
(define-constant MAX_CLAIM_AMOUNT u1000000) ;; 1M tokens max per claim

;; Data Variables
(define-data-var distribution-active bool false)
(define-data-var total-distributed uint u0)
(define-data-var distribution-cap uint u100000000) ;; 100M tokens total cap

;; Data Maps
;; User reputation system
(define-map user-reputation 
  { user: principal }
  {
    score: uint,
    last-updated: uint,
    activity-count: uint,
    verified: bool
  })

;; Token claims tracking
(define-map user-claims
  { user: principal }
  {
    total-claimed: uint,
    last-claim-block: uint,
    claim-count: uint
  })

;; Activity tracking for reputation building
(define-map user-activities
  { user: principal, activity-id: uint }
  {
    activity-type: (string-ascii 20),
    timestamp: uint,
    reputation-gained: uint,
    verified: bool
  })

;; Verification nodes for Sybil resistance
(define-map verification-nodes
  { node: principal }
  {
    active: bool,
    verification-count: uint,
    trust-score: uint
  })

;; Activity counter for unique activity IDs
(define-data-var next-activity-id uint u1)

;; Read-only functions
(define-read-only (get-user-reputation (user principal))
  (match (map-get? user-reputation { user: user })
    reputation (ok reputation)
    (err ERR_USER_NOT_FOUND)))

(define-read-only (get-user-claims (user principal))
  (match (map-get? user-claims { user: user })
    claims (ok claims)
    (ok { total-claimed: u0, last-claim-block: u0, claim-count: u0 })))

(define-read-only (is-distribution-active)
  (var-get distribution-active))

(define-read-only (get-total-distributed)
  (var-get total-distributed))

;; Private helper function for min
(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b))

(define-read-only (calculate-claim-amount (user principal))
  (let (
    (reputation-data (unwrap! (get-user-reputation user) ERR_USER_NOT_FOUND)))
    (let (
      (base-amount u1000)
      (reputation-multiplier (/ (get score reputation-data) u10))
      (claim-amount (+ base-amount reputation-multiplier)))
      (ok (min-uint claim-amount MAX_CLAIM_AMOUNT)))))

(define-read-only (can-claim-tokens (user principal))
  (let (
    (reputation-data (map-get? user-reputation { user: user }))
    (claims-data (map-get? user-claims { user: user })))
    (match reputation-data
      reputation (
        let (
          (last-claim-block (match claims-data
            claims (get last-claim-block claims)
            u0)))
          (and 
            (var-get distribution-active)
            (>= (get score reputation) MIN_REPUTATION_FOR_CLAIM)
            (get verified reputation)
            (< (+ last-claim-block COOLDOWN_PERIOD) stacks-block-height)))
      false)))

;; Private functions
(define-private (update-reputation-decay (user principal))
  (let (
    (current-reputation (unwrap! (get-user-reputation user) ERR_USER_NOT_FOUND)))
    (let (
      (blocks-passed (- stacks-block-height (get last-updated current-reputation)))
      (decay-amount (min-uint (get score current-reputation) (* blocks-passed REPUTATION_DECAY_RATE)))
      (new-score (- (get score current-reputation) decay-amount)))
      (map-set user-reputation 
        { user: user }
        (merge current-reputation { 
          score: new-score, 
          last-updated: stacks-block-height }))
      (ok new-score))))

;; Public functions

;; Initialize user reputation (anyone can call this for themselves)
(define-public (initialize-reputation)
  (let (
    (user tx-sender))
    (asserts! (is-none (map-get? user-reputation { user: user })) ERR_ALREADY_CLAIMED)
    (map-set user-reputation 
      { user: user }
      {
        score: u50, ;; Starting reputation
        last-updated: stacks-block-height,
        activity-count: u0,
        verified: false })
    (ok true)))

;; Add activity to build reputation
(define-public (add-activity (activity-type (string-ascii 20)) (reputation-gain uint))
  (let (
    (user tx-sender)
    (activity-id (var-get next-activity-id))
    (current-reputation (unwrap! (get-user-reputation user) ERR_USER_NOT_FOUND)))
    ;; Update activity counter
    (var-set next-activity-id (+ activity-id u1))
    
    ;; Record activity
    (map-set user-activities
      { user: user, activity-id: activity-id }
      {
        activity-type: activity-type,
        timestamp: stacks-block-height,
        reputation-gained: reputation-gain,
        verified: false })
    
    ;; Update user reputation
    (map-set user-reputation
      { user: user }
      (merge current-reputation {
        score: (+ (get score current-reputation) reputation-gain),
        activity-count: (+ (get activity-count current-reputation) u1),
        last-updated: stacks-block-height }))
    
    (ok activity-id)))

;; Verify activity (only verification nodes)
(define-public (verify-activity (user principal) (activity-id uint))
  (let (
    (verifier tx-sender)
    (node-data (unwrap! (map-get? verification-nodes { node: verifier }) ERR_NOT_AUTHORIZED))
    (activity-data (unwrap! (map-get? user-activities { user: user, activity-id: activity-id }) ERR_USER_NOT_FOUND))
    (user-rep-data (unwrap! (get-user-reputation user) ERR_USER_NOT_FOUND)))
    ;; Check if node is active
    (asserts! (get active node-data) ERR_NOT_AUTHORIZED)
    
    ;; Mark activity as verified
    (map-set user-activities
      { user: user, activity-id: activity-id }
      (merge activity-data { verified: true }))
    
    ;; Update user verification status if they have enough verified activities
    (if (>= (get activity-count user-rep-data) u5)
      (map-set user-reputation
        { user: user }
        (merge user-rep-data { verified: true }))
      true)
    
    ;; Update verifier stats
    (map-set verification-nodes
      { node: verifier }
      (merge node-data { 
        verification-count: (+ (get verification-count node-data) u1) }))
    
    (ok true)))

;; Claim tokens based on reputation
(define-public (claim-tokens)
  (let (
    (user tx-sender))
    ;; Check if user can claim first
    (asserts! (can-claim-tokens user) ERR_INSUFFICIENT_REPUTATION)
    
    ;; Get claim amount
    (let (
      (claim-amount (unwrap! (calculate-claim-amount user) ERR_USER_NOT_FOUND))
      (current-claims (unwrap! (get-user-claims user) ERR_USER_NOT_FOUND))
      (new-total (+ (var-get total-distributed) claim-amount)))
      
      ;; Check distribution cap
      (asserts! (<= new-total (var-get distribution-cap)) ERR_INVALID_AMOUNT)
      
      ;; Update user claims
      (map-set user-claims
        { user: user }
        {
          total-claimed: (+ (get total-claimed current-claims) claim-amount),
          last-claim-block: stacks-block-height,
          claim-count: (+ (get claim-count current-claims) u1) })
      
      ;; Update total distributed
      (var-set total-distributed new-total)
      
      ;; Apply reputation decay
      (try! (update-reputation-decay user))
      
      ;; Here you would mint/transfer tokens to the user
      ;; (ft-mint? drop-genesis-token claim-amount user)
      
      (ok claim-amount))))

;; Admin functions (only contract owner)
(define-public (set-distribution-active (active bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set distribution-active active)
    (ok true)))

(define-public (set-distribution-cap (new-cap uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set distribution-cap new-cap)
    (ok true)))

(define-public (add-verification-node (node principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set verification-nodes
      { node: node }
      {
        active: true,
        verification-count: u0,
        trust-score: u100 })
    (ok true)))

(define-public (remove-verification-node (node principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? verification-nodes { node: node })
      node-data (begin
        (map-set verification-nodes
          { node: node }
          (merge node-data { active: false }))
        (ok true))
      ERR_USER_NOT_FOUND)))

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set distribution-active false)
    (ok true)))