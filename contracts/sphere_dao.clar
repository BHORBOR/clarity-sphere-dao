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
    funds-requested: uint
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
    (funds-requested uint))
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
        funds-requested: funds-requested
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