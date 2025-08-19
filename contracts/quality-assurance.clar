;; Holiday and Event Decoration Services - Quality Assurance Contract
;; Tracks service quality metrics, customer satisfaction, and quality control processes

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-RATING (err u401))
(define-constant ERR-SERVICE-NOT-FOUND (err u402))
(define-constant ERR-FEEDBACK-NOT-FOUND (err u403))
(define-constant ERR-INSPECTION-NOT-FOUND (err u404))
(define-constant ERR-INVALID-INPUT (err u405))
(define-constant ERR-ALREADY-RATED (err u406))
(define-constant ERR-INVALID-STATUS (err u407))

;; Rating Scale (1-5 stars)
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)

;; Quality Categories
(define-constant QUALITY-TIMELINESS u1)
(define-constant QUALITY-CRAFTSMANSHIP u2)
(define-constant QUALITY-PROFESSIONALISM u3)
(define-constant QUALITY-CLEANLINESS u4)
(define-constant QUALITY-COMMUNICATION u5)

;; Issue Severity Levels
(define-constant SEVERITY-LOW u1)
(define-constant SEVERITY-MEDIUM u2)
(define-constant SEVERITY-HIGH u3)
(define-constant SEVERITY-CRITICAL u4)

;; Issue Status
(define-constant ISSUE-OPEN u1)
(define-constant ISSUE-IN-PROGRESS u2)
(define-constant ISSUE-RESOLVED u3)
(define-constant ISSUE-CLOSED u4)

;; Inspection Status
(define-constant INSPECTION-SCHEDULED u1)
(define-constant INSPECTION-COMPLETED u2)
(define-constant INSPECTION-FAILED u3)
(define-constant INSPECTION-PASSED u4)

;; Data Variables
(define-data-var quality-manager principal CONTRACT-OWNER)
(define-data-var next-feedback-id uint u1)
(define-data-var next-inspection-id uint u1)
(define-data-var next-issue-id uint u1)
(define-data-var minimum-rating-threshold uint u3)

;; Data Maps
(define-map service-feedback
  { feedback-id: uint }
  {
    service-id: uint,
    customer: principal,
    overall-rating: uint,
    timeliness-rating: uint,
    craftsmanship-rating: uint,
    professionalism-rating: uint,
    cleanliness-rating: uint,
    communication-rating: uint,
    comments: (string-ascii 500),
    would-recommend: bool,
    submitted-at: uint,
    verified: bool
  }
)

(define-map quality-inspections
  { inspection-id: uint }
  {
    service-id: uint,
    inspector: principal,
    inspection-date: uint,
    checklist-items: (list 20 bool),
    overall-score: uint,
    status: uint,
    notes: (string-ascii 300),
    photos-hash: (optional (string-ascii 64)),
    follow-up-required: bool
  }
)

(define-map quality-issues
  { issue-id: uint }
  {
    service-id: uint,
    reported-by: principal,
    issue-type: uint,
    severity: uint,
    description: (string-ascii 400),
    status: uint,
    assigned-to: (optional principal),
    resolution-notes: (string-ascii 300),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map crew-performance
  { crew: principal }
  {
    total-services: uint,
    average-rating: uint,
    total-rating-points: uint,
    inspection-pass-rate: uint,
    total-inspections: uint,
    passed-inspections: uint,
    issue-count: uint,
    last-updated: uint
  }
)

(define-map service-ratings
  { service-id: uint }
  {
    total-ratings: uint,
    average-rating: uint,
    rating-sum: uint,
    has-feedback: bool,
    inspection-score: (optional uint),
    quality-certified: bool
  }
)

(define-map quality-standards
  { standard-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    minimum-score: uint,
    weight: uint,
    active: bool
  }
)

(define-data-var next-standard-id uint u1)

;; Private Functions
(define-private (is-valid-rating (rating uint))
  (and (>= rating MIN-RATING) (<= rating MAX-RATING))
)

(define-private (is-valid-severity (severity uint))
  (and (>= severity SEVERITY-LOW) (<= severity SEVERITY-CRITICAL))
)

(define-private (is-valid-issue-status (status uint))
  (and (>= status ISSUE-OPEN) (<= status ISSUE-CLOSED))
)

(define-private (calculate-average-rating (total-points uint) (total-ratings uint))
  (if (> total-ratings u0)
    (/ total-points total-ratings)
    u0
  )
)

(define-private (update-crew-performance (crew principal) (rating uint) (inspection-passed bool))
  (let ((current-perf (default-to
                        { total-services: u0, average-rating: u0, total-rating-points: u0,
                          inspection-pass-rate: u0, total-inspections: u0, passed-inspections: u0,
                          issue-count: u0, last-updated: u0 }
                        (map-get? crew-performance { crew: crew }))))

    (let ((new-total-services (+ (get total-services current-perf) u1))
          (new-total-points (+ (get total-rating-points current-perf) rating))
          (new-total-inspections (+ (get total-inspections current-perf) u1))
          (new-passed-inspections (if inspection-passed
                                    (+ (get passed-inspections current-perf) u1)
                                    (get passed-inspections current-perf))))

      (map-set crew-performance
        { crew: crew }
        {
          total-services: new-total-services,
          average-rating: (calculate-average-rating new-total-points new-total-services),
          total-rating-points: new-total-points,
          inspection-pass-rate: (if (> new-total-inspections u0)
                                  (/ (* new-passed-inspections u100) new-total-inspections)
                                  u0),
          total-inspections: new-total-inspections,
          passed-inspections: new-passed-inspections,
          issue-count: (get issue-count current-perf),
          last-updated: block-height
        }
      )
    )
  )
)

;; Public Functions

;; Submit customer feedback
(define-public (submit-feedback
  (service-id uint)
  (overall-rating uint)
  (timeliness-rating uint)
  (craftsmanship-rating uint)
  (professionalism-rating uint)
  (cleanliness-rating uint)
  (communication-rating uint)
  (comments (string-ascii 500))
  (would-recommend bool)
)
  (let ((feedback-id (var-get next-feedback-id)))
    (asserts! (is-valid-rating overall-rating) ERR-INVALID-RATING)
    (asserts! (is-valid-rating timeliness-rating) ERR-INVALID-RATING)
    (asserts! (is-valid-rating craftsmanship-rating) ERR-INVALID-RATING)
    (asserts! (is-valid-rating professionalism-rating) ERR-INVALID-RATING)
    (asserts! (is-valid-rating cleanliness-rating) ERR-INVALID-RATING)
    (asserts! (is-valid-rating communication-rating) ERR-INVALID-RATING)

    ;; Check if service already has feedback from this customer
    (asserts! (is-none (map-get? service-ratings { service-id: service-id })) ERR-ALREADY-RATED)

    (map-set service-feedback
      { feedback-id: feedback-id }
      {
        service-id: service-id,
        customer: tx-sender,
        overall-rating: overall-rating,
        timeliness-rating: timeliness-rating,
        craftsmanship-rating: craftsmanship-rating,
        professionalism-rating: professionalism-rating,
        cleanliness-rating: cleanliness-rating,
        communication-rating: communication-rating,
        comments: comments,
        would-recommend: would-recommend,
        submitted-at: block-height,
        verified: false
      }
    )

    ;; Update service ratings
    (map-set service-ratings
      { service-id: service-id }
      {
        total-ratings: u1,
        average-rating: overall-rating,
        rating-sum: overall-rating,
        has-feedback: true,
        inspection-score: none,
        quality-certified: false
      }
    )

    (var-set next-feedback-id (+ feedback-id u1))
    (ok feedback-id)
  )
)

;; Conduct quality inspection (quality manager or authorized inspector only)
(define-public (conduct-inspection
  (service-id uint)
  (checklist-items (list 20 bool))
  (overall-score uint)
  (notes (string-ascii 300))
  (photos-hash (optional (string-ascii 64)))
)
  (let ((inspection-id (var-get next-inspection-id)))
    (asserts!
      (or (is-eq tx-sender (var-get quality-manager))
          ;; Add logic to check for authorized inspectors
          false)
      ERR-NOT-AUTHORIZED
    )
    (asserts! (and (>= overall-score u0) (<= overall-score u100)) ERR-INVALID-INPUT)

    (let ((passed (>= overall-score (var-get minimum-rating-threshold)))
          (status (if (>= overall-score (var-get minimum-rating-threshold))
                    INSPECTION-PASSED
                    INSPECTION-FAILED)))

      (map-set quality-inspections
        { inspection-id: inspection-id }
        {
          service-id: service-id,
          inspector: tx-sender,
          inspection-date: block-height,
          checklist-items: checklist-items,
          overall-score: overall-score,
          status: status,
          notes: notes,
          photos-hash: photos-hash,
          follow-up-required: (< overall-score u80)
        }
      )

      ;; Update service ratings with inspection score
      (let ((current-rating (default-to
                              { total-ratings: u0, average-rating: u0, rating-sum: u0,
                                has-feedback: false, inspection-score: none, quality-certified: false }
                              (map-get? service-ratings { service-id: service-id }))))
        (map-set service-ratings
          { service-id: service-id }
          (merge current-rating {
            inspection-score: (some overall-score),
            quality-certified: (and passed (get has-feedback current-rating))
          })
        )
      )

      (var-set next-inspection-id (+ inspection-id u1))
      (ok inspection-id)
    )
  )
)

;; Report quality issue
(define-public (report-issue
  (service-id uint)
  (issue-type uint)
  (severity uint)
  (description (string-ascii 400))
)
  (let ((issue-id (var-get next-issue-id)))
    (asserts! (is-valid-severity severity) ERR-INVALID-INPUT)
    (asserts! (and (>= issue-type u1) (<= issue-type u5)) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set quality-issues
      { issue-id: issue-id }
      {
        service-id: service-id,
        reported-by: tx-sender,
        issue-type: issue-type,
        severity: severity,
        description: description,
        status: ISSUE-OPEN,
        assigned-to: none,
        resolution-notes: "",
        created-at: block-height,
        resolved-at: none
      }
    )

    (var-set next-issue-id (+ issue-id u1))
    (ok issue-id)
  )
)

;; Assign issue to crew member (quality manager only)
(define-public (assign-issue (issue-id uint) (assignee principal))
  (let ((issue (unwrap! (map-get? quality-issues { issue-id: issue-id }) ERR-INVALID-INPUT)))
    (asserts! (is-eq tx-sender (var-get quality-manager)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status issue) ISSUE-OPEN) ERR-INVALID-STATUS)

    (map-set quality-issues
      { issue-id: issue-id }
      (merge issue {
        assigned-to: (some assignee),
        status: ISSUE-IN-PROGRESS
      })
    )
    (ok true)
  )
)

;; Resolve quality issue
(define-public (resolve-issue (issue-id uint) (resolution-notes (string-ascii 300)))
  (let ((issue (unwrap! (map-get? quality-issues { issue-id: issue-id }) ERR-INVALID-INPUT)))
    (asserts!
      (or (is-eq tx-sender (var-get quality-manager))
          (is-eq (some tx-sender) (get assigned-to issue)))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (is-eq (get status issue) ISSUE-IN-PROGRESS) ERR-INVALID-STATUS)

    (map-set quality-issues
      { issue-id: issue-id }
      (merge issue {
        status: ISSUE-RESOLVED,
        resolution-notes: resolution-notes,
        resolved-at: (some block-height)
      })
    )
    (ok true)
  )
)

;; Verify customer feedback (quality manager only)
(define-public (verify-feedback (feedback-id uint))
  (let ((feedback (unwrap! (map-get? service-feedback { feedback-id: feedback-id }) ERR-FEEDBACK-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get quality-manager)) ERR-NOT-AUTHORIZED)

    (map-set service-feedback
      { feedback-id: feedback-id }
      (merge feedback { verified: true })
    )
    (ok true)
  )
)

;; Set quality standard (quality manager only)
(define-public (set-quality-standard
  (name (string-ascii 100))
  (description (string-ascii 200))
  (minimum-score uint)
  (weight uint)
)
  (let ((standard-id (var-get next-standard-id)))
    (asserts! (is-eq tx-sender (var-get quality-manager)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= minimum-score u0) (<= minimum-score u100)) ERR-INVALID-INPUT)

    (map-set quality-standards
      { standard-id: standard-id }
      {
        name: name,
        description: description,
        minimum-score: minimum-score,
        weight: weight,
        active: true
      }
    )

    (var-set next-standard-id (+ standard-id u1))
    (ok standard-id)
  )
)

;; Read-only Functions

;; Get service feedback
(define-read-only (get-feedback (feedback-id uint))
  (map-get? service-feedback { feedback-id: feedback-id })
)

;; Get quality inspection
(define-read-only (get-inspection (inspection-id uint))
  (map-get? quality-inspections { inspection-id: inspection-id })
)

;; Get quality issue
(define-read-only (get-issue (issue-id uint))
  (map-get? quality-issues { issue-id: issue-id })
)

;; Get crew performance
(define-read-only (get-crew-performance (crew principal))
  (map-get? crew-performance { crew: crew })
)

;; Get service ratings
(define-read-only (get-service-ratings (service-id uint))
  (map-get? service-ratings { service-id: service-id })
)

;; Get quality standard
(define-read-only (get-quality-standard (standard-id uint))
  (map-get? quality-standards { standard-id: standard-id })
)

;; Check if service meets quality standards
(define-read-only (meets-quality-standards (service-id uint))
  (match (map-get? service-ratings { service-id: service-id })
    ratings (and (get has-feedback ratings)
                 (is-some (get inspection-score ratings))
                 (>= (get average-rating ratings) (var-get minimum-rating-threshold)))
    false
  )
)

;; Get next IDs
(define-read-only (get-next-feedback-id)
  (var-get next-feedback-id)
)

(define-read-only (get-next-inspection-id)
  (var-get next-inspection-id)
)

(define-read-only (get-next-issue-id)
  (var-get next-issue-id)
)

;; Get quality manager
(define-read-only (get-quality-manager)
  (var-get quality-manager)
)

;; Get minimum rating threshold
(define-read-only (get-minimum-rating-threshold)
  (var-get minimum-rating-threshold)
)
