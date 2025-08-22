;; fuel-points-loyalty.clar
;;
;; This contract defines a SIP-010 Fungible Token for a petrol station loyalty program.
;; The token, "FuelPoints" (FPT), is awarded to customers and can be redeemed for services.
;;
;; Conforms to the SIP-010 Fungible Token standard.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;; Constants ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_STATION_NOT_REGISTERED (err u103))
(define-constant ERR_REDEMPTION_VALUE_ZERO (err u104))
(define-constant ERR_INVALID_CONVERSION_RATE (err u105))
(define-constant ERR_MINT_AMOUNT_ZERO (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_AMOUNT (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))

;; Maximum values for security
(define-constant MAX_MINT_AMOUNT u1000000000000) ;; 1M tokens with 6 decimals
(define-constant MAX_CONVERSION_RATE u100000000) ;; Maximum conversion rate
(define-constant MIN_CONVERSION_RATE u1) ;; Minimum conversion rate

(define-fungible-token fuel-points)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Data Storage ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The name of the token
(define-data-var token-name (string-ascii 32) "FuelPoints")
;; The symbol of the token
(define-data-var token-symbol (string-ascii 10) "FPT")
;; The number of decimals for the token
(define-data-var token-decimals uint u6)
;; The total supply of the token
(define-data-var token-total-supply uint u0)
;; The URI for the token's metadata
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://gasup.rewards/metadata.json"))

;; Map of registered station principals authorized to mint/burn points
(define-map authorized-stations principal bool)

;; The conversion rate for redemption: 1 STX = this many FuelPoints
(define-data-var redemption-conversion-rate uint u1000) ;; e.g., 1000 FPT per STX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Input Validation Helpers ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; @desc Validates that a principal is not the zero address
;; @param account: Principal to validate
;; @returns bool
(define-private (is-valid-principal (account principal))
  (not (is-eq account 'ST000000000000000000002AMW42H))
)

;; @desc Validates mint/transfer amounts
;; @param amount: Amount to validate
;; @returns bool
(define-private (is-valid-amount (amount uint))
  (and (> amount u0) (<= amount MAX_MINT_AMOUNT))
)

;; @desc Validates conversion rate
;; @param rate: Rate to validate
;; @returns bool
(define-private (is-valid-conversion-rate (rate uint))
  (and (>= rate MIN_CONVERSION_RATE) (<= rate MAX_CONVERSION_RATE))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Administrative Functions ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; @desc Authorizes a new station to mint and redeem points.
;; @param station: The principal of the station to authorize.
;; @returns (response bool uint)
(define-public (add-authorized-station (station principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal station) ERR_INVALID_PRINCIPAL)
    (ok (map-set authorized-stations station true))
  )
)

;; @desc Revokes a station's authorization.
;; @param station: The principal of the station to revoke.
;; @returns (response bool uint)
(define-public (remove-authorized-station (station principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal station) ERR_INVALID_PRINCIPAL)
    (ok (map-set authorized-stations station false))
  )
)

;; @desc Sets the redemption conversion rate.
;; @param new-rate: The new rate of FuelPoints per STX.
;; @returns (response bool uint)
(define-public (set-conversion-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-conversion-rate new-rate) ERR_INVALID_CONVERSION_RATE)
    (ok (var-set redemption-conversion-rate new-rate))
  )
)

;; @desc Update the token URI. Can only be called by the contract owner.
;; @param new-uri: The new URI for the token metadata.
;; @returns (response bool uint)
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Basic validation - ensure URI is not empty
    (asserts! (> (len new-uri) u0) ERR_INVALID_PRINCIPAL)
    (ok (var-set token-uri (some new-uri)))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Core Loyalty Logic ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; @desc An authorized station awards loyalty points to a customer.
;; @param amount: The number of points to award.
;; @param recipient: The customer's principal.
;; @returns (response bool uint)
(define-public (award-points (amount uint) (recipient principal))
  (begin
    (asserts! (default-to false (map-get? authorized-stations tx-sender)) ERR_STATION_NOT_REGISTERED)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)

    (let ((current-supply (var-get token-total-supply))
          (new-supply (+ current-supply amount)))
      ;; Check for overflow
      (asserts! (>= new-supply current-supply) ERR_INVALID_AMOUNT)
      (var-set token-total-supply new-supply)
      (ft-mint? fuel-points amount recipient)
    )
  )
)

;; @desc A customer redeems points at an authorized station.
;; This function burns the tokens and emits redemption details.
;; @param amount: The number of points to redeem.
;; @param station: The principal of the station where points are redeemed.
;; @returns (response bool uint)
(define-public (redeem-points (amount uint) (station principal))
  (begin
    (asserts! (is-valid-principal station) ERR_INVALID_PRINCIPAL)
    (asserts! (default-to false (map-get? authorized-stations station)) ERR_STATION_NOT_REGISTERED)
    (asserts! (> amount u0) ERR_REDEMPTION_VALUE_ZERO)
    (asserts! (>= (ft-get-balance fuel-points tx-sender) amount) ERR_INSUFFICIENT_BALANCE)

    ;; Burn the tokens by transferring them to the contract owner
    (match (ft-transfer? fuel-points amount tx-sender CONTRACT_OWNER)
      success 
        (let ((rate (var-get redemption-conversion-rate))
              (current-supply (var-get token-total-supply)))
          ;; Update total supply to reflect burned tokens
          (var-set token-total-supply (- current-supply amount))
          (print
            {
              action: "redeem-points",
              customer: tx-sender,
              station: station,
              points-redeemed: amount,
              equivalent-stx-value: (/ (* amount u1000000) rate) ;; Value in microSTX
            }
          )
          (ok true)
        )
      error ERR_TRANSFER_FAILED
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; SIP-010 Required Functions ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; @desc Transfers tokens from the caller's account to a recipient.
;; @param amount: The number of tokens to transfer.
;; @param sender: The sender's principal.
;; @param recipient: The recipient's principal.
;; @param memo: An optional memo.
;; @returns (response bool uint)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance fuel-points sender) amount) ERR_INSUFFICIENT_BALANCE)

    (match (ft-transfer? fuel-points amount sender recipient)
      success 
        (begin
          (print {
            action: "transfer",
            amount: amount,
            sender: sender,
            recipient: recipient,
            memo: memo
          })
          (ok true)
        )
      error ERR_TRANSFER_FAILED
    )
  )
)

;; @desc Returns the name of the token.
;; @returns (response (string-ascii 32) uint)
(define-read-only (get-name)
  (ok (var-get token-name))
)

;; @desc Returns the symbol of the token.
;; @returns (response (string-ascii 10) uint)
(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

;; @desc Returns the number of decimals for the token.
;; @returns (response uint uint)
(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

;; @desc Returns the balance of a given principal.
;; @param owner: The principal to check.
;; @returns (response uint uint)
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance fuel-points owner))
)

;; @desc Returns the total supply of the token.
;; @returns (response uint uint)
(define-read-only (get-total-supply)
  (ok (var-get token-total-supply))
)

;; @desc Returns the URI for the token's metadata.
;; @returns (response (optional (string-utf8 256)) uint)
(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Read-Only Helpers ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; @desc Checks if a station principal is authorized.
;; @param station: The principal to check.
;; @returns bool
(define-read-only (is-station-authorized (station principal))
  (default-to false (map-get? authorized-stations station))
)

;; @desc Returns the current redemption conversion rate.
;; @returns uint
(define-read-only (get-redemption-rate)
  (var-get redemption-conversion-rate)
)

;; @desc Returns contract owner
;; @returns principal
(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)