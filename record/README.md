# AstroNet: Collaborative Astronomical Data Verification Contract

## Overview
AstroNet is a decentralized smart contract designed to facilitate the verification and cataloging of astronomical observations through community-driven peer review. The contract incentivizes accurate astronomical data submission while ensuring reliability through a structured peer-review system. Astronomers are rewarded for valid observations, and inaccurate submissions are penalized.

## Features
- **Decentralized Data Submission**: Astronomers can submit astronomical observations by staking tokens.
- **Peer Review Mechanism**: Observations undergo community peer review, requiring a consensus before cataloging.
- **Token-Based Incentives**: Contributors are rewarded with grants when their observations are verified.
- **Fraud Prevention**: Invalid or inaccurate submissions lead to penalties.
- **Grant Fund Management**: The contract owner can allocate funds to reward astronomers.
- **Transparent Tracking**: Read-only functions allow anyone to check observation statuses.

## Smart Contract Details

### Constants
- **`contract-owner`**: The address that deploys the contract.
- **`minimum-tokens`**: Minimum required tokens for data submission (`500` tokens).
- **`max-observation-length`**: Maximum allowed observation description length (`256` characters).
- **`max-grant-fund`**: Maximum allowed contributions to the grant fund (`1,000,000` tokens).

### Data Structures
- **`celestial-observations` (Map)**: Stores observation data with celestial IDs and timestamps.
- **`observation-reviews` (Map)**: Tracks the number of reviews and catalog status.
- **`grant-fund` (Variable)**: Holds the funds available for rewarding contributors.

## Functions

### Public Functions

#### `register-celestial-body (celestial-id uint, initial-observation (string-utf8 256)) -> (ok true | err)`
Registers a new celestial observation.
- **Validates inputs** (celestial ID, observation length, and available tokens).
- **Locks submission tokens** from the sender.
- **Stores the observation in `celestial-observations`**.

#### `submit-observation-data (celestial-id uint, observation-data (string-utf8 256)) -> (ok true | err)`
Allows users to submit observation data.
- **Checks for duplicate submissions** within the same epoch.
- **Requires token staking** to submit data.
- **Stores observation and initializes peer review tracking**.

#### `peer-review-observation (celestial-id uint, observation-epoch uint, is-accurate bool) -> (ok true | err)`
Allows peers to review an observation.
- **Validates celestial ID and epoch**.
- **Prevents self-review**.
- **Increases review count**.
- If **three positive reviews are reached**, the data is cataloged, and the astronomer is rewarded.
- If **reviewers find an observation inaccurate**, the submitter is penalized.

#### `contribute-to-grant-fund (amount uint) -> (ok true | err)`
Allows the contract owner to add funds to the grant pool.
- **Validates ownership and amount constraints** before increasing the `grant-fund`.

### Read-Only Functions

#### `is-observation-cataloged (celestial-id uint, observation-epoch uint) -> (bool)`
Returns whether an observation has been cataloged after peer review.

## How It Works
1. **An astronomer submits an observation** by staking tokens.
2. **Peers review the submission** and validate its accuracy.
3. **If at least three peers approve** an observation, it is cataloged.
4. **The astronomer is rewarded** with their tokens plus an additional grant.
5. **If found inaccurate**, the submitter loses a portion of their staked tokens.
6. **The contract owner can replenish the grant fund** to sustain rewards.

## Error Codes
- **`u100`**: Unauthorized access.
- **`u101`**: Invalid data format.
- **`u102`**: Insufficient tokens.
- **`u103`**: Duplicate submission.
- **`u104`**: Invalid input parameters.

## Deployment & Usage
1. **Deploy the contract** on a blockchain that supports Clarity smart contracts.
2. **Users interact with the contract** via a blockchain interface or frontend application.
3. **Reviewers validate data**, ensuring accurate astronomical information.

## Future Enhancements
- Integration with **on-chain reputation systems** to identify reliable reviewers.
- A **data visualization dashboard** for tracking peer-reviewed astronomical data.
- **Interoperability with telescope APIs** for automated data submission.
- **Multi-tier rewards** based on observation difficulty.

## Conclusion
AstroNet aims to revolutionize how astronomical data is validated by leveraging blockchain technology. By integrating a peer-reviewed system with tokenized incentives, it ensures the accuracy and credibility of astronomical observations in a decentralized manner.

