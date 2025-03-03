;; SphereDAO Contract
(define-data-var dao-name (string-ascii 50) "SphereDAO")

;; Add vote tracking maps
(define-map proposal-votes {proposal-id: uint, voter: principal} bool)
(define-map milestone-voter-registry {proposal-id: uint, milestone-index: uint, voter: principal} bool)
(define-map milestone-votes uint {
  proposal-id: uint,
  milestone-index: uint,
  votes-for: uint,
  votes-against: uint
})

;; Original maps remain unchanged...

;; Enhanced error constants
(define-constant ERR_ALREADY_VOTED (err u107))
(define-constant ERR_INVALID_DEADLINE (err u108))
(define-constant ERR_MILESTONE_FUNDS_EXCEED_TOTAL (err u109))
(define-constant ERR_INVALID_MILESTONE_DEADLINE (err u110))

;; Enhanced proposal creation with milestone deadline validation
(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (deadline uint)
    (funds-requested uint)
    (milestones (list 5 {
      title: (string-ascii 100),
      description: (string-ascii 200),
      deadline: uint,
      funds: uint,
      status: (string-ascii 20)
    })))
  (let (
    (proposal-id (+ (var-get proposal-count) u1))
    (total-milestone-funds (fold + (map get-milestone-funds milestones) u0))
  )
    (asserts! (is-some (map-get? members tx-sender)) ERR_NOT_MEMBER)
    (asserts! (> deadline block-height) ERR_INVALID_DEADLINE)
    (asserts! (<= total-milestone-funds funds-requested) ERR_MILESTONE_FUNDS_EXCEED_TOTAL)
    ;; Validate milestone deadlines
    (asserts! (validate-milestone-deadlines milestones deadline) ERR_INVALID_MILESTONE_DEADLINE)
    
    (map-set proposals proposal-id
      {
        title: title,
        description: description,
        proposer: tx-sender,
        status: "active",
        votes-for: u0,
        votes-against: u0,
        deadline: deadline,
        funds-requested: funds-requested,
        milestones: milestones
      })
    (var-set proposal-count proposal-id)
    (ok proposal-id)))

;; Enhanced milestone voting with safer vote counting
(define-public (vote-on-milestone (proposal-id uint) (milestone-index uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (milestone-vote-id (generate-milestone-vote-id proposal-id milestone-index))
    (vote-key {proposal-id: proposal-id, milestone-index: milestone-index, voter: tx-sender})
    (current-votes (default-to 
      {proposal-id: proposal-id, milestone-index: milestone-index, votes-for: u0, votes-against: u0} 
      (map-get? milestone-votes milestone-vote-id)))
  )
    (asserts! (< milestone-index (len (get milestones proposal))) ERR_MILESTONE_NOT_FOUND)
    (asserts! (is-none (map-get? milestone-voter-registry vote-key)) ERR_ALREADY_VOTED)
    
    (map-set milestone-voter-registry vote-key true)
    (map-set milestone-votes milestone-vote-id
      (merge current-votes 
        (if vote
          {votes-for: (+ (get votes-for current-votes) u1)}
          {votes-against: (+ (get votes-against current-votes) u1)})))
    (ok true)))

;; New helper functions
(define-private (generate-milestone-vote-id (proposal-id uint) (milestone-index uint))
  (+ (* proposal-id u1000) milestone-index))

(define-private (validate-milestone-deadlines 
  (milestones (list 5 {
    title: (string-ascii 100),
    description: (string-ascii 200),
    deadline: uint,
    funds: uint,
    status: (string-ascii 20)
  }))
  (proposal-deadline uint))
  (fold and (map validate-milestone-deadline milestones proposal-deadline) true))

(define-private (validate-milestone-deadline 
  (milestone {
    title: (string-ascii 100),
    description: (string-ascii 200),
    deadline: uint,
    funds: uint,
    status: (string-ascii 20)
  })
  (proposal-deadline uint))
  (<= (get deadline milestone) proposal-deadline))

;; New getter function for milestone voting status
(define-read-only (get-milestone-votes (proposal-id uint) (milestone-index uint))
  (map-get? milestone-votes (generate-milestone-vote-id proposal-id milestone-index)))
