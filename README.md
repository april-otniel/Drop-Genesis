# Drop Genesis - Merit-based Token Distribution

A Clarity smart contract built on the Stacks blockchain that enables merit-based token distribution with built-in Sybil resistance mechanisms. Users earn tokens through verified activities and reputation building, creating a fair and sustainable distribution model.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Core Functions](#core-functions)
- [Reputation System](#reputation-system)
- [Sybil Resistance](#sybil-resistance)
- [Token Claiming](#token-claiming)
- [Admin Functions](#admin-functions)
- [Error Codes](#error-codes)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security Considerations](#security-considerations)

## Overview

Drop Genesis implements a sophisticated token distribution system that rewards genuine user participation while preventing Sybil attacks. The contract tracks user activities, builds reputation scores over time, and allows users to claim tokens based on their verified contributions to the ecosystem.

## Features

- **Merit-based Distribution**: Token allocation based on user reputation and verified activities
- **Sybil Resistance**: Multi-layer verification system using trusted nodes
- **Reputation Decay**: Prevents inactive users from hoarding reputation indefinitely
- **Cooldown Periods**: Prevents spam and encourages sustainable participation
- **Activity Verification**: Third-party verification of user activities
- **Distribution Controls**: Admin controls for managing token distribution parameters
- **Emergency Pause**: Safety mechanism for halting distribution in emergencies

## Architecture

### Core Components

1. **Reputation System**: Tracks user reputation based on verified activities
2. **Activity Tracking**: Records and verifies user activities
3. **Verification Network**: Trusted nodes that verify user activities
4. **Token Distribution**: Calculates and distributes tokens based on merit
5. **Admin Controls**: Management functions for contract administration

### Data Structures

- `user-reputation`: Stores reputation scores, verification status, and activity counts
- `user-claims`: Tracks token claims, timestamps, and claim history
- `user-activities`: Records individual activities and their verification status
- `verification-nodes`: Manages the network of activity verifiers

## Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Basic understanding of Clarity smart contracts
- Stacks wallet for testing

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd drop-genesis

# Check contract syntax
clarinet check

# Run tests
npm install
npm test
```

## Core Functions

### User Functions

#### `initialize-reputation()`
Initializes a user's reputation profile. Must be called before participating in the ecosystem.

```clarity
(contract-call? .drop-genesis initialize-reputation)
```

#### `add-activity(activity-type, reputation-gain)`
Records a new activity for reputation building.

```clarity
(contract-call? .drop-genesis add-activity "social-post" u10)
```

#### `claim-tokens()`
Claims tokens based on current reputation and eligibility.

```clarity
(contract-call? .drop-genesis claim-tokens)
```

### Read-Only Functions

#### `get-user-reputation(user)`
Returns a user's current reputation data.

#### `calculate-claim-amount(user)`
Calculates how many tokens a user can claim.

#### `can-claim-tokens(user)`
Checks if a user is eligible to claim tokens.

## Reputation System

### How It Works

1. **Initial Reputation**: New users start with 50 reputation points
2. **Activity Rewards**: Users gain reputation through verified activities
3. **Reputation Decay**: Reputation decreases over time to prevent hoarding
4. **Verification Requirement**: Users must be verified to claim tokens

### Reputation Formula

```
Base Claim Amount = 1,000 tokens
Reputation Multiplier = User Reputation ÷ 10
Final Claim = Base Amount + Reputation Multiplier (capped at 1M tokens)
```

### Key Parameters

- **Minimum Reputation**: 100 points required for token claims
- **Decay Rate**: 1 point per block for inactive users
- **Cooldown Period**: 144 blocks (~24 hours) between claims
- **Starting Reputation**: 50 points for new users

## Sybil Resistance

### Multi-Layer Protection

1. **Verification Nodes**: Trusted entities that verify user activities
2. **Activity Verification**: Activities must be verified to count toward reputation
3. **Minimum Activity Threshold**: 5+ verified activities required for user verification
4. **Reputation Decay**: Prevents dormant accounts from maintaining high reputation

### Verification Process

1. User performs an activity and records it via `add-activity()`
2. Verification node reviews and verifies the activity via `verify-activity()`
3. Verified activities contribute to user reputation and verification status
4. Users with 5+ verified activities become eligible for token claims

## Token Claiming

### Eligibility Requirements

- ✅ Distribution must be active
- ✅ User reputation ≥ 100 points
- ✅ User must be verified (5+ verified activities)
- ✅ Cooldown period must have passed (144+ blocks since last claim)
- ✅ Total distribution under cap

### Claiming Process

```clarity
;; Check eligibility
(contract-call? .drop-genesis can-claim-tokens user-principal)

;; Calculate claim amount
(contract-call? .drop-genesis calculate-claim-amount user-principal)

;; Claim tokens
(contract-call? .drop-genesis claim-tokens)
```

## Admin Functions

### Distribution Management

#### `set-distribution-active(active)`
Enable or disable token distribution.

#### `set-distribution-cap(new-cap)`
Update the maximum total tokens that can be distributed.

#### `emergency-pause()`
Immediately halt all token distribution.

### Verification Network

#### `add-verification-node(node)`
Add a new verification node to the network.

#### `remove-verification-node(node)`
Deactivate a verification node.

### Usage Example

```clarity
;; Enable distribution
(contract-call? .drop-genesis set-distribution-active true)

;; Add verification node
(contract-call? .drop-genesis add-verification-node 'SP1ABCDEF...)

;; Set distribution cap to 100M tokens
(contract-call? .drop-genesis set-distribution-cap u100000000)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100  | `ERR_NOT_AUTHORIZED` | Caller not authorized for this action |
| 101  | `ERR_ALREADY_CLAIMED` | User has already performed this action |
| 102  | `ERR_INSUFFICIENT_REPUTATION` | User doesn't meet reputation requirements |
| 103  | `ERR_DISTRIBUTION_NOT_ACTIVE` | Token distribution is currently disabled |
| 104  | `ERR_INVALID_AMOUNT` | Requested amount exceeds limits |
| 105  | `ERR_USER_NOT_FOUND` | User data not found |
| 106  | `ERR_COOLDOWN_ACTIVE` | User must wait before next action |

## Testing

### Running Tests

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run specific test file
npx clarinet test tests/drop-genesis_test.ts
```

### Test Coverage

Tests should cover:
- ✅ User reputation initialization
- ✅ Activity addition and verification
- ✅ Token claiming logic
- ✅ Sybil resistance mechanisms
- ✅ Admin functions
- ✅ Error conditions
- ✅ Edge cases

## Deployment

### Testnet Deployment

```bash
# Deploy to testnet
clarinet deployments generate --testnet

# Apply deployment
clarinet deployments apply -p deployments/default.testnet-plan.yaml
```

### Mainnet Considerations

Before mainnet deployment:

1. **Comprehensive Testing**: Ensure all functions work correctly
2. **Security Audit**: Professional audit of the smart contract
3. **Parameter Tuning**: Adjust reputation thresholds and decay rates
4. **Verification Network**: Establish trusted verification nodes
5. **Monitoring**: Set up monitoring for contract activity

## Security Considerations

### Potential Risks

1. **Verification Node Compromise**: Malicious verifiers could approve fake activities
2. **Reputation Gaming**: Users might attempt to manipulate the reputation system
3. **Admin Key Security**: Contract owner keys must be properly secured
4. **Distribution Cap**: Ensure cap is set appropriately to prevent token inflation

### Mitigations

- **Multi-signature Admin**: Use multi-sig for admin functions
- **Verification Node Monitoring**: Monitor verification node behavior
- **Regular Audits**: Periodic security audits of the contract
- **Emergency Controls**: Emergency pause functionality
- **Parameter Updates**: Ability to adjust parameters as needed

### Best Practices

- Never share admin private keys
- Use hardware wallets for admin functions
- Monitor contract activity regularly
- Keep verification nodes updated and secure
- Document all parameter changes

## Contributing

We welcome contributions! Please read our contributing guidelines and submit pull requests for any improvements.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Join our Discord community
- Read the documentation at [docs.dropgenesis.io](https://docs.dropgenesis.io)
