;; P2P Car Rental Platform Contract
;; A decentralized peer-to-peer car rental system on Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-car-not-found (err u103))
(define-constant err-car-not-available (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-rental-not-found (err u106))

;; Data structures
(define-map cars
  uint ;; car-id
  {
    owner: principal,
    make: (string-ascii 32),
    model: (string-ascii 32),
    year: uint,
    license-plate: (string-ascii 16),
    daily-rate: uint, ;; in microSTX
    location: (string-ascii 64),
    is-available: bool,
    total-rentals: uint
  })

(define-map rentals
  uint ;; rental-id
  {
    car-id: uint,
    renter: principal,
    owner: principal,
    start-date: uint,
    end-date: uint,
    total-cost: uint,
    is-active: bool,
    created-at: uint
  })

(define-map owner-cars principal (list 20 uint))
(define-map renter-history principal (list 50 uint))

(define-data-var next-car-id uint u1)
(define-data-var next-rental-id uint u1)
(define-data-var total-cars uint u0)
(define-data-var total-rentals uint u0)

;; Function 1: List Car for Rental
;; Allows car owners to list their vehicles for rental
(define-public (list-car-for-rental 
    (make (string-ascii 32))
    (model (string-ascii 32))
    (year uint)
    (license-plate (string-ascii 16))
    (daily-rate uint)
    (location (string-ascii 64)))
  (let ((car-id (var-get next-car-id)))
    (begin
      ;; Validate input data
      (asserts! (> (len make) u0) err-invalid-data)
      (asserts! (> (len model) u0) err-invalid-data)
      (asserts! (and (>= year u1990) (<= year u2030)) err-invalid-data)
      (asserts! (> (len license-plate) u0) err-invalid-data)
      (asserts! (> daily-rate u0) err-invalid-data)
      (asserts! (> (len location) u0) err-invalid-data)
      
      ;; Create car listing
      (map-set cars car-id {
        owner: tx-sender,
        make: make,
        model: model,
        year: year,
        license-plate: license-plate,
        daily-rate: daily-rate,
        location: location,
        is-available: true,
        total-rentals: u0
      })
      
      ;; Update owner's car list
      (let ((current-cars (default-to (list) (map-get? owner-cars tx-sender))))
        (map-set owner-cars tx-sender 
          (unwrap! (as-max-len? (append current-cars car-id) u20) err-invalid-data)))
      
      ;; Update counters
      (var-set next-car-id (+ car-id u1))
      (var-set total-cars (+ (var-get total-cars) u1))
      
      (ok car-id))))

;; Function 2: Book Car Rental
;; Allows users to book available cars for rental
(define-public (book-car-rental 
    (car-id uint)
    (rental-days uint))
  (let ((car-info (unwrap! (map-get? cars car-id) err-car-not-found))
        (rental-id (var-get next-rental-id))
        (total-cost (* (get daily-rate car-info) rental-days)))
    (begin
      ;; Validate rental request
      (asserts! (> rental-days u0) err-invalid-data)
      (asserts! (<= rental-days u30) err-invalid-data) ;; Max 30 days
      (asserts! (get is-available car-info) err-car-not-available)
      (asserts! (not (is-eq tx-sender (get owner car-info))) err-not-authorized)
      
      ;; Transfer payment from renter to car owner
      (try! (stx-transfer? total-cost tx-sender (get owner car-info)))
      
      ;; Create rental record
      (map-set rentals rental-id {
        car-id: car-id,
        renter: tx-sender,
        owner: (get owner car-info),
        start-date: block-height,
        end-date: (+ block-height (* rental-days u144)), ;; ~1 day = 144 blocks
        total-cost: total-cost,
        is-active: true,
        created-at: block-height
      })
      
      ;; Mark car as unavailable
      (map-set cars car-id (merge car-info {
        is-available: false,
        total-rentals: (+ (get total-rentals car-info) u1)
      }))
      
      ;; Update renter history
      (let ((current-history (default-to (list) (map-get? renter-history tx-sender))))
        (map-set renter-history tx-sender 
          (unwrap! (as-max-len? (append current-history rental-id) u50) err-invalid-data)))
      
      ;; Update counters
      (var-set next-rental-id (+ rental-id u1))
      (var-set total-rentals (+ (var-get total-rentals) u1))
      
      (ok rental-id))))

;; Helper function: Get car details
(define-read-only (get-car-details (car-id uint))
  (ok (map-get? cars car-id)))

;; Helper function: Get rental details
(define-read-only (get-rental-details (rental-id uint))
  (ok (map-get? rentals rental-id)))

;; Get owner's listed cars
(define-read-only (get-owner-cars (owner principal))
  (ok (default-to (list) (map-get? owner-cars owner))))

;; Get renter's rental history
(define-read-only (get-renter-history (renter principal))
  (ok (default-to (list) (map-get? renter-history renter))))

;; Get total statistics
(define-read-only (get-platform-stats)
  (ok {
    total-cars: (var-get total-cars),
    total-rentals: (var-get total-rentals),
    next-car-id: (var-get next-car-id),
    next-rental-id: (var-get next-rental-id)
  }))

;; Check if car is available
(define-read-only (is-car-available (car-id uint))
  (match (map-get? cars car-id)
    car-info (ok (get is-available car-info))
    (err err-car-not-found)))