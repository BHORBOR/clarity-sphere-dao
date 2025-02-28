;; SphereDAO Contract
(define-data-var dao-name (string-ascii 50) "SphereDAO")

;; Add vote tracking maps
(define-map proposal-votes {proposal-id: uint, voter: principal} bool)
(define-map milestone-voter-registry {proposal-id: uint, milestone-index: uint, voter: principal} bool)

;; Original maps
(define-map members principal
  {
    role: (string-ascii 20),
    joining-time: uint,
    voting-power: uint
  }
)

(define-map proposals uint 
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    deadline: uint,
    funds-requested: uint,
    milestones: (list 5 {
      title: (string-ascii 100),
      description: (string-ascii 200),
      deadline: uint,
      funds: uint,
      status: (string-ascii 20)
    })
  }
)

;; ... [previous constants and other map definitions remain unchanged]

;; Add new error constants
(define-constant ERR_ALREADY_VOTED (err u107))
(define-constant ERR_INVALID_DEADLINE (err u108))
(define-constant ERR_MILESTONE_FUNDS_EXCEED_TOTAL (err u109))

;; Enhanced proposal creation with validations
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

;; Enhanced voting with double-vote prevention
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (vote-key {proposal-id: proposal-id, voter: tx-sender})
  )
    (asserts! (is-eq (get status proposal) "active") (err u105))
    (asserts! (is-none (map-get? proposal-votes vote-key)) ERR_ALREADY_VOTED)
    
    (map-set proposal-votes vote-key true)
    (if vote
      (map-set proposals proposal-id 
        (merge proposal { votes-for: (+ (get votes-for proposal) (get voting-power member)) }))
      (map-set proposals proposal-id 
        (merge proposal { votes-against: (+ (get votes-against proposal) (get voting-power member)) })))
    (ok true)))

;; Enhanced milestone voting with double-vote prevention
(define-public (vote-on-milestone (proposal-id uint) (milestone-index uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (milestone-vote-id (+ (* proposal-id u100) milestone-index))
    (vote-key {proposal-id: proposal-id, milestone-index: milestone-index, voter: tx-sender})
  )
    (asserts! (< milestone-index (len (get milestones proposal))) ERR_MILESTONE_NOT_FOUND)
    (asserts! (is-none (map-get? milestone-voter-registry vote-key)) ERR_ALREADY_VOTED)
    
    (map-set milestone-voter-registry vote-key true)
    (map-set milestone-votes milestone-vote-id
      {
        proposal-id: proposal-id,
        milestone-index: milestone-index,
        votes-for: (if vote 
          (+ (default-to u0 (get votes-for (map-get? milestone-votes milestone-vote-id))) u1)
          (get votes-for (default-to {votes-for: u0} (map-get? milestone-votes milestone-vote-id)))),
        votes-against: (if vote
          (get votes-against (default-to {votes-against: u0} (map-get? milestone-votes milestone-vote-id)))
          (+ (default-to u0 (get votes-against (map-get? milestone-votes milestone-vote-id))) u1))
      })
    (ok true)))

;; Helper function to sum milestone funds
(define-private (get-milestone-funds (milestone {
  title: (string-ascii 100),
  description: (string-ascii 200),
  deadline: uint,
  funds: uint,
  status: (string-ascii 20)
}))
  (get funds milestone))

;; [Rest of the contract remains unchanged]
