
;; Peer-to-Peer Car Rental Contract
;; Owners can list cars, renters can book cars

(define-map cars
  uint
  { owner: principal, model: (string-ascii 50), is-rented: bool })

(define-map rentals
  {car-id: uint, renter: principal}
  bool)

(define-data-var car-count uint u0)

(define-constant err-already-rented (err u100))
(define-constant err-not-found (err u101))

;; List a car on the platform
(define-public (list-car (model (string-ascii 50)))
  (let ((id (var-get car-count)))
    (begin
      (map-set cars id { owner: tx-sender, model: model, is-rented: false })
      (var-set car-count (+ id u1))
      (ok id))))

;; Rent a car by ID
(define-public (rent-car (car-id uint))
  (match (map-get? cars car-id)
    car-data
    (begin
      (asserts! (not (get is-rented car-data)) err-already-rented)
      (map-set cars car-id
        { owner: (get owner car-data),
          model: (get model car-data),
          is-rented: true })
      (map-set rentals {car-id: car-id, renter: tx-sender} true)
      (ok true))
    err-not-found))
