(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_USER_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_DAILY_LIMIT_EXCEEDED (err u103))
(define-constant ERR_ALREADY_REGISTERED (err u104))
(define-constant ERR_INVALID_DATE (err u105))
(define-constant ERR_GOAL_NOT_FOUND (err u106))
(define-constant ERR_GOAL_ALREADY_EXISTS (err u107))
(define-constant ERR_INVALID_GOAL_DURATION (err u108))
(define-constant ERR_GOAL_EXPIRED (err u109))

(define-data-var total-users uint u0)
(define-data-var total-water-used uint u0)

(define-map users
    principal
    {
        registered-at: uint,
        daily-limit: uint,
        total-usage: uint,
        conservation-score: uint,
        is-active: bool,
    }
)

(define-map daily-usage
    {
        user: principal,
        date: uint,
    }
    {
        amount: uint,
        timestamp: uint,
    }
)

(define-map monthly-stats
    {
        user: principal,
        month: uint,
        year: uint,
    }
    {
        total-amount: uint,
        days-recorded: uint,
        average-daily: uint,
    }
)

(define-map conservation-rewards
    principal
    {
        total-rewards: uint,
        last-reward-block: uint,
    }
)

(define-map leaderboard
    uint
    {
        user: principal,
        conservation-score: uint,
    }
)

(define-map user-goals
    principal
    {
        target-reduction-percentage: uint,
        start-date: uint,
        end-date: uint,
        baseline-usage: uint,
        current-progress: uint,
        is-achieved: bool,
        goal-type: (string-ascii 20),
    }
)

(define-map goal-achievements
    {
        user: principal,
        goal-id: uint,
    }
    {
        achieved-at: uint,
        actual-reduction: uint,
        bonus-points: uint,
    }
)

(define-read-only (get-user-info (user principal))
    (map-get? users user)
)

(define-read-only (get-daily-usage
        (user principal)
        (date uint)
    )
    (map-get? daily-usage {
        user: user,
        date: date,
    })
)

(define-read-only (get-monthly-stats
        (user principal)
        (month uint)
        (year uint)
    )
    (map-get? monthly-stats {
        user: user,
        month: month,
        year: year,
    })
)

(define-read-only (get-conservation-rewards (user principal))
    (map-get? conservation-rewards user)
)

(define-read-only (get-user-goal (user principal))
    (map-get? user-goals user)
)

(define-read-only (get-goal-achievement
        (user principal)
        (goal-id uint)
    )
    (map-get? goal-achievements {
        user: user,
        goal-id: goal-id,
    })
)

(define-read-only (get-total-users)
    (var-get total-users)
)

(define-read-only (get-total-water-used)
    (var-get total-water-used)
)

(define-read-only (get-current-date)
    (/ (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
        u86400
    )
)

(define-read-only (is-user-registered (user principal))
    (is-some (map-get? users user))
)

(define-read-only (calculate-conservation-score (user principal))
    (let (
            (user-info (unwrap! (map-get? users user) u0))
            (total-usage (get total-usage user-info))
            (daily-limit (get daily-limit user-info))
            (days-registered (- (get-current-date) (get registered-at user-info)))
            (max-possible-usage (* daily-limit days-registered))
        )
        (if (> max-possible-usage u0)
            (* (- max-possible-usage total-usage) u100)
            u0
        )
    )
)

(define-public (register-user (daily-limit uint))
    (let (
            (user tx-sender)
            (current-date (get-current-date))
        )
        (asserts! (> daily-limit u0) ERR_INVALID_AMOUNT)
        (asserts! (is-none (map-get? users user)) ERR_ALREADY_REGISTERED)

        (map-set users user {
            registered-at: current-date,
            daily-limit: daily-limit,
            total-usage: u0,
            conservation-score: u0,
            is-active: true,
        })

        (map-set conservation-rewards user {
            total-rewards: u0,
            last-reward-block: stacks-block-height,
        })

        (var-set total-users (+ (var-get total-users) u1))
        (ok true)
    )
)

(define-public (update-daily-limit (new-limit uint))
    (let (
            (user tx-sender)
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
        )
        (asserts! (> new-limit u0) ERR_INVALID_AMOUNT)

        (map-set users user (merge user-info { daily-limit: new-limit }))
        (ok true)
    )
)

(define-public (record-usage (amount uint))
    (let (
            (user tx-sender)
            (current-date (get-current-date))
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
            (daily-limit (get daily-limit user-info))
            (existing-daily-usage (default-to {
                amount: u0,
                timestamp: u0,
            }
                (map-get? daily-usage {
                    user: user,
                    date: current-date,
                })
            ))
            (current-daily-total (get amount existing-daily-usage))
            (new-daily-total (+ current-daily-total amount))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= new-daily-total daily-limit) ERR_DAILY_LIMIT_EXCEEDED)

        (map-set daily-usage {
            user: user,
            date: current-date,
        } {
            amount: new-daily-total,
            timestamp: stacks-block-height,
        })

        (map-set users user
            (merge user-info {
                total-usage: (+ (get total-usage user-info) amount),
                conservation-score: (calculate-conservation-score user),
            })
        )

        (var-set total-water-used (+ (var-get total-water-used) amount))
        (unwrap-panic (update-monthly-stats user amount current-date))
        (unwrap-panic (check-conservation-reward user))
        (ok true)
    )
)

(define-private (update-monthly-stats
        (user principal)
        (amount uint)
        (date uint)
    )
    (let (
            (month (mod (/ date u30) u12))
            (year (+ u2023 (/ date u365)))
            (existing-stats (default-to {
                total-amount: u0,
                days-recorded: u0,
                average-daily: u0,
            }
                (map-get? monthly-stats {
                    user: user,
                    month: month,
                    year: year,
                })
            ))
            (new-total (+ (get total-amount existing-stats) amount))
            (new-days (+ (get days-recorded existing-stats) u1))
            (new-average (/ new-total new-days))
        )
        (map-set monthly-stats {
            user: user,
            month: month,
            year: year,
        } {
            total-amount: new-total,
            days-recorded: new-days,
            average-daily: new-average,
        })
        (ok true)
    )
)

(define-private (check-conservation-reward (user principal))
    (let (
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
            (conservation-score (get conservation-score user-info))
            (reward-info (unwrap! (map-get? conservation-rewards user) ERR_USER_NOT_FOUND))
            (last-reward-block (get last-reward-block reward-info))
            (blocks-since-reward (- stacks-block-height last-reward-block))
        )
        (if (and (> conservation-score u5000) (> blocks-since-reward u144))
            (begin
                (map-set conservation-rewards user {
                    total-rewards: (+ (get total-rewards reward-info) u10),
                    last-reward-block: stacks-block-height,
                })
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (deactivate-account)
    (let (
            (user tx-sender)
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
        )
        (map-set users user (merge user-info { is-active: false }))
        (ok true)
    )
)

(define-public (reactivate-account)
    (let (
            (user tx-sender)
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
        )
        (map-set users user (merge user-info { is-active: true }))
        (ok true)
    )
)

(define-read-only (get-user-usage-history
        (user principal)
        (start-date uint)
        (end-date uint)
    )
    (if (and (<= start-date end-date) (<= (- end-date start-date) u30))
        (fold check-date-usage (list start-date) (list))
        (list)
    )
)

(define-private (check-date-usage
        (date uint)
        (acc (list 30 {
            date: uint,
            amount: uint,
        }))
    )
    (let (
            (usage (map-get? daily-usage {
                user: tx-sender,
                date: date,
            }))
            (amount (if (is-some usage)
                (get amount (unwrap-panic usage))
                u0
            ))
        )
        (unwrap-panic (as-max-len?
            (append acc {
                date: date,
                amount: amount,
            })
            u30
        ))
    )
)

(define-read-only (get-top-conservers (limit uint))
    (let ((max-limit (if (<= limit u10)
            limit
            u10
        )))
        (fold build-leaderboard (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list))
    )
)

(define-private (build-leaderboard
        (index uint)
        (acc (list 10 {
            user: principal,
            score: uint,
        }))
    )
    (let ((entry (map-get? leaderboard index)))
        (if (is-some entry)
            (let ((leaderboard-entry (unwrap-panic entry)))
                (unwrap-panic (as-max-len?
                    (append acc {
                        user: (get user leaderboard-entry),
                        score: (get conservation-score leaderboard-entry),
                    })
                    u10
                ))
            )
            acc
        )
    )
)

(define-public (update-leaderboard (user principal))
    (let (
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
            (conservation-score (get conservation-score user-info))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)

        (map-set leaderboard (var-get total-users) {
            user: user,
            conservation-score: conservation-score,
        })
        (ok true)
    )
)

(define-read-only (calculate-water-savings (user principal))
    (let (
            (user-info (unwrap! (map-get? users user) u0))
            (total-usage (get total-usage user-info))
            (daily-limit (get daily-limit user-info))
            (days-registered (- (get-current-date) (get registered-at user-info)))
            (potential-usage (* daily-limit days-registered))
        )
        (if (> potential-usage total-usage)
            (- potential-usage total-usage)
            u0
        )
    )
)

(define-read-only (calculate-goal-progress (user principal))
    (let (
            (goal (unwrap! (map-get? user-goals user) u0))
            (user-info (unwrap! (map-get? users user) u0))
            (baseline-usage (get baseline-usage goal))
            (current-total (get total-usage user-info))
            (days-since-goal (- (get-current-date) (get start-date goal)))
            (projected-baseline (* baseline-usage days-since-goal))
        )
        (if (> projected-baseline u0)
            (/ (* (- projected-baseline current-total) u100) projected-baseline)
            u0
        )
    )
)

(define-public (bulk-update-users (users-list (list 50 principal)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (fold update-single-user users-list (ok true))
    )
)

(define-private (update-single-user
        (user principal)
        (prev-response (response bool uint))
    )
    (let ((user-info (map-get? users user)))
        (if (is-some user-info)
            (let (
                    (info (unwrap-panic user-info))
                    (new-score (calculate-conservation-score user))
                )
                (map-set users user
                    (merge info { conservation-score: new-score })
                )
                (ok true)
            )
            prev-response
        )
    )
)

(define-public (set-conservation-goal
        (target-reduction-percentage uint)
        (duration-days uint)
        (goal-type (string-ascii 20))
    )
    (let (
            (user tx-sender)
            (current-date (get-current-date))
            (end-date (+ current-date duration-days))
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
            (days-registered (- current-date (get registered-at user-info)))
            (daily-avg (if (> days-registered u0)
                (/ (get total-usage user-info) days-registered)
                u0
            ))
        )
        (asserts!
            (and (> target-reduction-percentage u0) (<= target-reduction-percentage u100))
            ERR_INVALID_AMOUNT
        )
        (asserts! (and (> duration-days u0) (<= duration-days u365))
            ERR_INVALID_GOAL_DURATION
        )
        (asserts! (is-none (map-get? user-goals user)) ERR_GOAL_ALREADY_EXISTS)

        (map-set user-goals user {
            target-reduction-percentage: target-reduction-percentage,
            start-date: current-date,
            end-date: end-date,
            baseline-usage: daily-avg,
            current-progress: u0,
            is-achieved: false,
            goal-type: goal-type,
        })
        (ok true)
    )
)

(define-public (update-goal-progress)
    (let (
            (user tx-sender)
            (goal (unwrap! (map-get? user-goals user) ERR_GOAL_NOT_FOUND))
            (current-date (get-current-date))
            (progress (calculate-goal-progress user))
            (target-percentage (get target-reduction-percentage goal))
        )
        (asserts! (<= current-date (get end-date goal)) ERR_GOAL_EXPIRED)

        (map-set user-goals user (merge goal { current-progress: progress }))

        (if (>= progress target-percentage)
            (begin
                (map-set user-goals user (merge goal { is-achieved: true }))
                (unwrap-panic (award-goal-achievement user progress))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-private (award-goal-achievement
        (user principal)
        (actual-reduction uint)
    )
    (let (
            (goal (unwrap! (map-get? user-goals user) ERR_GOAL_NOT_FOUND))
            (bonus-multiplier (if (> actual-reduction (get target-reduction-percentage goal))
                u2
                u1
            ))
            (bonus-points (* actual-reduction bonus-multiplier))
            (user-info (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
            (reward-info (unwrap! (map-get? conservation-rewards user) ERR_USER_NOT_FOUND))
        )
        (map-set goal-achievements {
            user: user,
            goal-id: (get-current-date),
        } {
            achieved-at: (get-current-date),
            actual-reduction: actual-reduction,
            bonus-points: bonus-points,
        })

        (map-set conservation-rewards user {
            total-rewards: (+ (get total-rewards reward-info) bonus-points),
            last-reward-block: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (reset-goal)
    (let (
            (user tx-sender)
            (goal (unwrap! (map-get? user-goals user) ERR_GOAL_NOT_FOUND))
        )
        (map-delete user-goals user)
        (ok true)
    )
)
