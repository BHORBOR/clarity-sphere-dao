;; SphereDAO Contract
(define-data-var dao-name (string-ascii 50) "SphereDAO")
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

(define-map milestone-votes uint 
  {
    proposal-id: uint,
    milestone-index: uint,
    votes-for: uint,
    votes-against: uint
  }
)

(define-data-var proposal-count uint u0)
(define-data-var treasury-balance uint u0)

;; Constants
(define-constant ERR_NOT_MEMBER (err u100))
(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_MILESTONE (err u105))
(define-constant ERR_MILESTONE_NOT_FOUND (err u106))

;; Member Management
(define-public (add-member (new-member principal) (role (string-ascii 20)))
  (let ((sender-info (unwrap! (get-member-info tx-sender) ERR_UNAUTHORIZED)))
    (if (is-eq (get role sender-info) "admin")
      (begin
        (map-set members new-member {
          role: role,
          joining-time: block-height,
          voting-power: u1
        })
        (ok true))
      ERR_UNAUTHORIZED)))

(define-read-only (get-member-info (member principal))
  (ok (map-get? members member)))

;; Proposal Management
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
  (let ((proposal-id (+ (var-get proposal-count) u1)))
    (asserts! (is-some (map-get? members tx-sender)) ERR_NOT_MEMBER)
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

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
  )
    (asserts! (is-eq (get status proposal) "active") (err u105))
    (if vote
      (map-set proposals proposal-id 
        (merge proposal { votes-for: (+ (get votes-for proposal) (get voting-power member)) }))
      (map-set proposals proposal-id 
        (merge proposal { votes-against: (+ (get votes-against proposal) (get voting-power member)) })))
    (ok true)))

;; Milestone Management  
(define-public (vote-on-milestone (proposal-id uint) (milestone-index uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (milestone-vote-id (+ (* proposal-id u100) milestone-index))
  )
    (asserts! (< milestone-index (len (get milestones proposal))) ERR_MILESTONE_NOT_FOUND)
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

(define-public (complete-milestone (proposal-id uint) (milestone-index uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (member (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
    (milestones (get milestones proposal))
  )
    (asserts! (< milestone-index (len milestones)) ERR_MILESTONE_NOT_FOUND)
    (asserts! (is-eq (get role member) "admin") ERR_UNAUTHORIZED)
    
    (let ((updated-milestones (map-set-status milestones milestone-index "completed")))
      (map-set proposals proposal-id
        (merge proposal { milestones: updated-milestones }))
      (ok true))))

;; Treasury Management
(define-public (deposit-funds (amount uint))
  (begin
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok true)))

(define-public (withdraw-funds (amount uint) (recipient principal))
  (let ((sender-info (unwrap! (get-member-info tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-eq (get role sender-info) "admin") ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get treasury-balance)) ERR_INSUFFICIENT_FUNDS)
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (ok true)))

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id)))

(define-read-only (get-treasury-balance)
  (ok (var-get treasury-balance)))

(define-read-only (get-milestone-votes (proposal-id uint) (milestone-index uint))
  (ok (map-get? milestone-votes (+ (* proposal-id u100) milestone-index))))

;; Helper functions
(define-private (map-set-status (milestones (list 5 {
    title: (string-ascii 100),
    description: (string-ascii 200),
    deadline: uint,
    funds: uint,
    status: (string-ascii 20)
  })) 
  (index uint)
  (new-status (string-ascii 20)))
  (map-index milestones index 
    (lambda (milestone) 
      (merge milestone {status: new-status}))))
