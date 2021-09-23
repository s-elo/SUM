pragma solidity ^0.6;

import "../../../lib/Math.sol";
import "../../../lib/SafeMath.sol";
import "../../../lib/SignedSafeMath.sol";

import {IncentiveMechanism, IncentiveMechanism64} from "./IncentiveMechanism.sol";
import {Ownable} from "../ownership/Ownable.sol";

/**
 * A base class for contracts that want to accept deposits to incentivise good contributions of information.
 */
contract Stakeable is Ownable, IncentiveMechanism {
    using SafeMath for uint256;

    /**
     * A refund has been issued.
     */
    event Refund(
        /**
         * The recipient of the refund which is the one who originally submitted the data contribution.
         */
        address recipient,
        /**
         * The amount refunded.
         */
        uint256 amount
    );

    /**
     * An award for reporting data has been issued.
     */
    event Report(
        /**
         * The one who submitted the report.
         */
        address recipient,
        /**
         * The amount awarded.
         */
        uint256 amount
    );

    /**
     * Multiplicative factor for the cost calculation.
     */
    uint256 public costWeight;

    /**
     * The last time that data was updated in seconds since the epoch.
     */
    uint256 public lastUpdateTimeS;

    constructor(
        // Parameters in chronological order.
        uint32 _refundWaitTimeS,
        uint32 _ownerClaimWaitTimeS,
        uint32 _anyAddressClaimWaitTimeS,
        uint80 _costWeight
    )
        public
        Ownable()
        IncentiveMechanism(
            _refundWaitTimeS,
            _ownerClaimWaitTimeS,
            _anyAddressClaimWaitTimeS
        )
    {
        require(
            _refundWaitTimeS <= _ownerClaimWaitTimeS,
            "Owner claim wait time must be at least the refund wait time."
        );
        require(
            _ownerClaimWaitTimeS <= _anyAddressClaimWaitTimeS,
            "Owner claim wait time must be less than the any address claim wait time."
        );

        costWeight = _costWeight;

        lastUpdateTimeS = now; // solium-disable-line security/no-block-members
    }

    /**
     * @return The amount of wei required to add data now.
     *
     * Note that since this method uses `now` which depends on the last block time,
     * when testing, the output of this function may not change over time unless blocks are created.
     * @dev see also `getNextAddDataCost(uint)`
     */
    function getNextAddDataCost() public view override returns (uint256) {
        return getNextAddDataCost(now); // solium-disable-line security/no-block-members
    }

    /**
     * @param currentTimeS The current time in seconds since the epoch.
     *
     * @return The amount of wei required to add data at `currentTimeS`.
     */
    function getNextAddDataCost(uint256 currentTimeS)
        public
        view
        override
        returns (uint256)
    {
        // if costWeight == 0, the cost will be always 0
        if (costWeight == 0) {
            return 0;
        }

        // Value sent is in wei (1E18 wei = 1 ether).
        require(
            lastUpdateTimeS <= currentTimeS,
            "The last update time is after the current time."
        );
        // No SafeMath check needed because already done above.
        uint256 divisor = currentTimeS - lastUpdateTimeS;

        if (divisor == 0) {
            // when the currentTimeS is the lastUpdateTimeS
            divisor = 1;
        } else {
            divisor = Math.sqrt(divisor);
            // TODO Check that sqrt is "safe".
        }

        // 1 hours == 60*60 == 3600
        // return costWeight * 3600 / divisor
        // when the currentTimeS becomes greater and greater than lastUpdateTimeS
        // the divisor will be greater and greater
        // so the costWeight will be less and less
        return costWeight.mul(1 hours).div(divisor);
    }
}

contract Stakeable64 is IncentiveMechanism64, Stakeable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    constructor(
        uint32 _refundWaitTimeS,
        uint32 _ownerClaimWaitTimeS,
        uint32 _anyAddressClaimWaitTimeS,
        uint80 _costWeight
    )
        public
        Stakeable(
            _refundWaitTimeS,
            _ownerClaimWaitTimeS,
            _anyAddressClaimWaitTimeS,
            _costWeight
        )
    {
        // solium-disable-previous-line no-empty-blocks
    }

    function getNextAddDataCost(
        int64[] memory, /* data */
        uint64 /* classification */
    ) public view override returns (uint256) {
        // Do not consider the data.
        return getNextAddDataCost();
    }

    function handleAddData(
        uint256 msgValue,
        int64[] memory data,
        uint64 classification
    ) public override onlyOwner returns (uint256 cost) {
        // since in this case, the data is not consider
        // the cost is completely determined by the currentTimeS - lastUpdateTimeS
        // it is also a return value (will be given to the DataHandler)
        cost = getNextAddDataCost(data, classification);
        require(msgValue >= cost, "Didn't pay enough for the deposit.");

        // just update some parameters
        lastUpdateTimeS = now; // solium-disable-line security/no-block-members
        totalSubmitted = totalSubmitted.add(1);
    }

    function handleRefund(
        address submitter,
        int64[] memory, /* data */
        uint64 classification,
        uint256 addedTime,
        uint256 claimableAmount,
        bool claimedBySubmitter,
        uint64 prediction,
        uint256 /* numClaims */
    ) public override onlyOwner returns (uint256 refundAmount) {
        // directly refund the rest claimable amount...
        // if the following requirements are met
        refundAmount = claimableAmount;

        // Make sure deposit can be taken.
        require(!claimedBySubmitter, "Deposit already claimed by submitter.");
        require(refundAmount > 0, "There is no reward left to claim.");
        require(
            now - addedTime >= refundWaitTimeS,
            "Not enough time has passed."
        ); // solium-disable-line security/no-block-members
        require(
            prediction == classification,
            "The model doesn't agree with your contribution."
        );

        // if the above requirements are met
        addressStats[submitter].numValid += 1;
        totalGoodDataCount = totalGoodDataCount.add(1);
        emit Refund(submitter, refundAmount);
    }

    function handleReport(
        address reporter,
        int64[] memory, /* data */
        uint64 classification,
        uint256 addedTime,
        address originalAuthor,
        uint256 initialDeposit,
        uint256 claimableAmount,
        bool claimedByReporter,
        uint64 prediction,
        uint256 /* numClaims */
    ) public override onlyOwner returns (uint256 rewardAmount) {
        // Make sure deposit can be taken.
        require(claimableAmount > 0, "There is no reward left to claim.");
        uint256 timeSinceAddedS = now - addedTime; // solium-disable-line security/no-block-members

        // if the time is long enough for owner to claim the remianing deposit
        // and the reporter is the owner
        // then just take it all
        if (timeSinceAddedS >= ownerClaimWaitTimeS && reporter == owner) {
            rewardAmount = claimableAmount;
        }
        // if the time is long enough for anyone to claim
        // then just take it all no matter who
        else if (timeSinceAddedS >= anyAddressClaimWaitTimeS) {
            // Enough time has passed, give the entire remaining deposit to the reporter.
            rewardAmount = claimableAmount;
        } else {
            // Don't allow someone to claim back their own deposit if their data was wrong.
            // They can still claim it from another address 
            // but they will have had to have sent good data from that address.
            require(
                reporter != originalAuthor,
                "Cannot take your own deposit."
            );

            require(!claimedByReporter, "Deposit already claimed by reporter.");
            require(
                timeSinceAddedS >= refundWaitTimeS,
                "Not enough time has passed."
            );

            // the data has already been used to update the model
            // only the prediction is not right
            // the report can be considered as "good"
            require(
                prediction != classification,
                "The model should not agree with the contribution."
            );

            // if all the above requirements are met
            // then see "how good the reporter is"
            // it is quite easy to be a good reporter
            // as long as contributed one good data before
            uint256 numGoodForReporter = addressStats[reporter].numValid;
            require(
                numGoodForReporter > 0,
                "The sender has not sent any good data."
            );

            // Weight the reward by the proportion of good data sent (maybe square the resulting value).
            // One nice reason to do this is to discourage someone from adding bad data through one address
            // and then just using another address to get their full deposit back.
            // rewardAmount = initialDeposit * numGoodForReporter / totalGoodDataCount
            rewardAmount = initialDeposit.mul(numGoodForReporter).div(
                totalGoodDataCount
            );
            if (rewardAmount == 0 || rewardAmount > claimableAmount) {
                // There is too little left to divide up. Just give everything to this reporter.
                rewardAmount = claimableAmount;
            }
        }

        emit Report(reporter, rewardAmount);
    }
}
