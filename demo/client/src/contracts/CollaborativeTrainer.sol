pragma solidity ^0.6;

import "../../lib/SafeMath.sol";

import {Classifier64} from "./classification/Classifier.sol";
import {DataHandler64} from "./data/DataHandler.sol";
import {IncentiveMechanism64} from "./incentive/IncentiveMechanism.sol";

/**
 * The main interface to sharing updatable models on the blockchain.
 */
contract CollaborativeTrainer {
    // The name of the model
    string public name;
    // A description of the model
    string public description;
    // the encoder that the model uses to encoder data
    string public encoder;

    constructor(
        string memory _name,
        string memory _description,
        string memory _encoder
    ) public {
        name = _name;
        description = _description;
        encoder = _encoder;
    }
}

/**
 * The main interface to Decentralized & Collaborative AI on the Blockchain.
 * For classifiers that use data with 64-bit values.
 */
// Using IoC even though it's more expensive, it's easier to work with.
// Those wishing to optimize can change the code to use inheritance and do other optimizations before deploying.
// We can also make a script that generates the required files based on several parameters.
contract CollaborativeTrainer64 is CollaborativeTrainer {
    using SafeMath for uint256;

    /** Data has been added. */
    event AddData(
        /**
         * The data stored.
         */
        int64[] d,
        /**
         * The classification for the data.
         */
        uint64 c,
        /**
         * The time it was added.
         */
        uint256 t,
        /**
         * The address that added the data.
         */
        address indexed sender,
        uint256 cost
    );

    DataHandler64 public dataHandler;
    IncentiveMechanism64 public incentiveMechanism;
    Classifier64 public classifier;

    constructor(
        string memory _name,
        string memory _description,
        string memory _encoder,
        DataHandler64 _dataHandler,
        IncentiveMechanism64 _incentiveMechanism,
        Classifier64 _classifier
    )
        public
        // _name, _description, and _encoder
        // are inherited from CollaborativeTrainer
        CollaborativeTrainer(_name, _description, _encoder)
    {
        dataHandler = _dataHandler;
        incentiveMechanism = _incentiveMechanism;
        classifier = _classifier;
    }

    /**
     * Update the model.
     *
     * @param data A single sample of training data for the model.
     * @param classification The label for `data`.
     */
    function addData(int64[] memory data, uint64 classification)
        public
        payable
    {
        // how much need to be deposited
        uint256 cost = incentiveMechanism.handleAddData(
            msg.value,
            data,
            classification
        );
        // added time (current time)
        uint256 time = dataHandler.handleAddData(
            msg.sender,
            cost,
            data,
            classification
        );

        // update the model
        classifier.update(data, classification);

        // Safe subtraction because cost <= msg.value.
        uint256 remaining = msg.value - cost;
        if (remaining > 0) {
            // give back to the data provider
            msg.sender.transfer(remaining);
        }

        // Emit here so that it's easier to catch.
        emit AddData(data, classification, time, msg.sender, cost);
    }

    /**
     * Attempt a refund for the deposit given with submitted data.
     * Must be called by the address that originally submitted the data.
     *
     * @param data The data for which to attempt a refund.
     * @param classification The label originally submitted with `data`.
     * @param addedTime The time when the data was added.
     */
    function refund(
        int64[] memory data,
        uint64 classification,
        uint256 addedTime
    ) public {
        /*
        claimableAmount: The amount that can be claimed for the refund.
        claimedBySubmitter: `true` if the data has already been claimed by `submitter`, otherwise `false`.
        numClaims: The number of claims that have been made for the contribution before this request.
         */
        (
            uint256 claimableAmount,
            bool claimedBySubmitter,
            uint256 numClaims
        ) = dataHandler.handleRefund(
                msg.sender,
                data,
                classification,
                addedTime
            );

        // use the sample to get the prediction
        // then give the incentiveMechanism to handle
        uint64 prediction = classifier.predict(data);

        // give the above params to incentiveMechanism
        // and get the final refund amount
        uint256 refundAmount = incentiveMechanism.handleRefund(
            msg.sender,
            data,
            classification,
            addedTime,
            claimableAmount,
            claimedBySubmitter,
            prediction,
            numClaims
        );
        msg.sender.transfer(refundAmount);
    }

    /**
     * Report bad or old data and attempt to get a reward.
     *
     * @param data The data to report.
     * @param classification The label originally submitted with `data`.
     * @param addedTime The time when the data was added.
     * @param originalAuthor The address that originally added the data.
     */
    function report(
        int64[] memory data,
        uint64 classification,
        uint256 addedTime,
        address originalAuthor
    ) public {
        /**
        initialDeposit: The amount that was initially deposited when the data contribution was submitted.
        claimableAmount: The amount remainining that can be claimed.
        claimedByReporter: `true` if the data has already been claimed by `reporter`, otherwise `false`.
        numClaims: The number of claims that have been made for the contribution before this request.
        dataKey: The key to the stored data.
         */
        (
            uint256 initialDeposit,
            uint256 claimableAmount,
            bool claimedByReporter,
            uint256 numClaims,
            bytes32 dataKey
        ) = dataHandler.handleReport(
                msg.sender,
                data,
                classification,
                addedTime,
                originalAuthor
            );

        uint64 prediction = classifier.predict(data);

        // determine the reward amount
        uint256 rewardAmount = incentiveMechanism.handleReport(
            msg.sender,
            data,
            classification,
            addedTime,
            originalAuthor,
            initialDeposit,
            claimableAmount,
            claimedByReporter,
            prediction,
            numClaims
        );

        // update the claimable amount after this reward (the remianing of the original deposit)
        dataHandler.updateClaimableAmount(dataKey, rewardAmount);

        msg.sender.transfer(rewardAmount);
    }
}
