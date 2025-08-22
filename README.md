# FuelPoints Loyalty Contract

A Stacks blockchain smart contract implementing a SIP-010 compliant fungible token for petrol station loyalty programs. The FuelPoints (FPT) token allows gas stations to reward customers with loyalty points that can be redeemed for services and discounts.

## Overview

The FuelPoints contract enables:
- **Point Awarding**: Authorized gas stations can mint loyalty points for customers
- **Point Redemption**: Customers can redeem points at participating stations
- **Station Management**: Contract owner can authorize/revoke gas station access
- **Token Transfer**: Standard SIP-010 token transfer functionality
- **Rate Management**: Configurable conversion rates between points and STX value

## Token Details

- **Name**: FuelPoints
- **Symbol**: FPT
- **Decimals**: 6
- **Standard**: SIP-010 Fungible Token
- **Blockchain**: Stacks

## Contract Architecture

### Constants
- **Security Limits**: Maximum mint amounts, conversion rate bounds
- **Error Codes**: Comprehensive error handling system
- **Owner Management**: Immutable contract owner set at deployment

### Core Features

#### 1. Administrative Functions
- `add-authorized-station(station)` - Authorize a gas station
- `remove-authorized-station(station)` - Revoke station authorization
- `set-conversion-rate(rate)` - Update point-to-STX conversion rate
- `set-token-uri(uri)` - Update token metadata URI

#### 2. Loyalty Operations
- `award-points(amount, recipient)` - Station awards points to customer
- `redeem-points(amount, station)` - Customer redeems points at station

#### 3. SIP-010 Token Functions
- `transfer(amount, sender, recipient, memo)` - Transfer tokens
- `get-balance(owner)` - Check token balance
- `get-total-supply()` - Get total token supply
- Standard metadata functions (name, symbol, decimals, URI)

## Security Features

### Input Validation
- **Principal Validation**: Prevents zero-address operations
- **Amount Bounds**: Limits on token amounts to prevent overflow
- **Rate Validation**: Conversion rate bounds checking
- **Authorization Checks**: Only authorized entities can perform restricted operations

### Anti-Abuse Measures
- **Maximum Limits**: Caps on mint amounts and conversion rates
- **Overflow Protection**: Safe arithmetic operations
- **Balance Verification**: Explicit balance checks before transfers
- **Proper Token Burning**: Correct total supply tracking

## Usage Examples

### For Gas Station Operators

#### 1. Getting Authorized
```clarity
;; Contract owner authorizes your station
(contract-call? .fuel-points-loyalty add-authorized-station 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### 2. Awarding Points to Customers
```clarity
;; Award 100 FPT to customer for fuel purchase
(contract-call? .fuel-points-loyalty award-points u100000000 'ST2CUSTOMER...)
```

### For Customers

#### 1. Check Your Balance
```clarity
;; Check your FuelPoints balance
(contract-call? .fuel-points-loyalty get-balance 'ST2CUSTOMER...)
```

#### 2. Redeem Points
```clarity
;; Redeem 50 FPT at authorized station
(contract-call? .fuel-points-loyalty redeem-points u50000000 'ST1STATION...)
```

#### 3. Transfer Points
```clarity
;; Transfer points to another user
(contract-call? .fuel-points-loyalty transfer u25000000 tx-sender 'ST2RECIPIENT... none)
```

### For Contract Owner

#### 1. Manage Conversion Rate
```clarity
;; Set 1000 FPT = 1 STX
(contract-call? .fuel-points-loyalty set-conversion-rate u1000)
```

#### 2. Update Metadata
```clarity
;; Update token metadata URI
(contract-call? .fuel-points-loyalty set-token-uri u"https://gasup.rewards/metadata-v2.json")
```

## Deployment Guide

### Prerequisites
- Clarinet CLI (v0.31.1 or compatible)
- Stacks account with STX for deployment
- Access to Stacks blockchain (mainnet/testnet)

### Steps

1. **Install Clarinet**
   ```bash
   npm install -g @stacks/clarinet
   ```

2. **Initialize Project**
   ```bash
   clarinet new fuel-points-project
   cd fuel-points-project
   ```

3. **Add Contract**
   ```bash
   # Copy the contract code to contracts/fuel-points-loyalty.clar
   ```

4. **Validate Contract**
   ```bash
   clarinet check
   ```

5. **Run Tests**
   ```bash
   clarinet test
   ```

6. **Deploy to Network**
   ```bash
   # Deploy to testnet
   clarinet deploy --testnet

   # Deploy to mainnet
   clarinet deploy --mainnet
   ```

## Integration Guide

### Frontend Integration

#### Using Stacks.js
```javascript
import { 
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  uintCV,
  principalCV
} from '@stacks/transactions';

// Award points to customer
const awardPointsTx = await makeContractCall({
  contractAddress: 'ST1CONTRACTOWNER...',
  contractName: 'fuel-points-loyalty',
  functionName: 'award-points',
  functionArgs: [uintCV(100000000), principalCV('ST2CUSTOMER...')],
  senderKey: stationPrivateKey,
  anchorMode: AnchorMode.Any,
});
```

#### Checking Balances
```javascript
import { callReadOnlyFunction } from '@stacks/transactions';

const balance = await callReadOnlyFunction({
  contractAddress: 'ST1CONTRACTOWNER...',
  contractName: 'fuel-points-loyalty',
  functionName: 'get-balance',
  functionArgs: [principalCV('ST2CUSTOMER...')],
});
```

### Backend Integration

#### Point of Sale Integration
```javascript
class FuelPointsManager {
  async awardPointsForPurchase(customerAddress, purchaseAmount) {
    // Calculate points based on purchase (e.g., 1 point per dollar)
    const points = Math.floor(purchaseAmount * 1000000); // 6 decimals

    return await this.contractCall('award-points', [
      uintCV(points),
      principalCV(customerAddress)
    ]);
  }

  async processRedemption(customerAddress, pointsToRedeem) {
    return await this.contractCall('redeem-points', [
      uintCV(pointsToRedeem),
      principalCV(this.stationAddress)
    ]);
  }
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller not authorized for operation |
| u101 | ERR_NOT_TOKEN_OWNER | Not the owner of tokens being transferred |
| u102 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| u103 | ERR_STATION_NOT_REGISTERED | Gas station not authorized |
| u104 | ERR_REDEMPTION_VALUE_ZERO | Cannot redeem zero points |
| u105 | ERR_INVALID_CONVERSION_RATE | Invalid conversion rate |
| u106 | ERR_MINT_AMOUNT_ZERO | Cannot mint zero tokens |
| u107 | ERR_INVALID_PRINCIPAL | Invalid principal address |
| u108 | ERR_INVALID_AMOUNT | Invalid amount (out of bounds) |
| u109 | ERR_TRANSFER_FAILED | Token transfer failed |

## Testing

### Unit Tests
```bash
# Run all tests
clarinet test

# Run specific test
clarinet test tests/fuel-points-loyalty_test.ts
```

### Example Test Cases
- Station authorization and revocation
- Point awarding with various amounts
- Point redemption validation
- Transfer functionality
- Error condition handling
- Overflow protection

## Governance

### Contract Owner Responsibilities
- Authorize legitimate gas stations
- Revoke compromised or fraudulent stations
- Set fair conversion rates
- Maintain token metadata
- Monitor for suspicious activity

### Station Operator Guidelines
- Only award points for legitimate purchases
- Maintain customer privacy
- Honor point redemptions promptly
- Report suspicious activity

## Security Considerations

### Best Practices
- **Private Key Security**: Secure storage of station private keys
- **Rate Limiting**: Implement frontend rate limiting for operations
- **Monitoring**: Monitor for unusual point awarding patterns
- **Regular Audits**: Periodic review of authorized stations

### Known Limitations
- Contract owner has significant control (consider multisig)
- No built-in rate limiting (implement off-chain)
- Point expiration not implemented (consider adding)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Run `clarinet check` to ensure no warnings
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support or questions:
- Create an issue in the repository
- Contact the development team
- Check the Stacks documentation at [docs.stacks.co](https://docs.stacks.co)

## Changelog

### v1.0.0
- Initial release with SIP-010 compliance
- Basic loyalty point functionality
- Security enhancements and input validation
- Comprehensive error handling