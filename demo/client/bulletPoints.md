# Answers for previous uncertainty

## How to store the models?

1. The models, namely those parameters, are stored in the samrt contracts or blockchain as states.

2. Note that a state can be a complex variable such as being a structure or even a contract

3. When we add a new data to update the params, we are actually changing the states with some gas,
   but prediction doesnt need any gas since the states are not changed.

## How to handle the submitted data?

1. The data will not be stored in the blockchain, only some meta-data of that particular sample
   will be stored such as the added time and claimable amount etc. These meta-data will help
   IncentiveMechanism to determine the required deposit, refund and reward amount.

2. The meta-data can be access by the corresponding hash or key of that sample.

3. The original data will be notify through the AddData event
   so that the client-side (every client-side or node) can get the newly added data and
   store them whereever they want. In this case, in the database.

## How to determine the deposit (Stakeable)?

1. When a new data is being added, it will be first given to the IncentiveMechanism
   to determine the depodit.

2. By knowing the costWeight (a factor), the lastUpdatedTimeS and the currentTimeS
   the deposit will be costWeight * 3600 / (lastUpdatedTimeS - currentTimeS)

3. The longer the time has passed since last update time, the less the deposit will be.

4. the costWeight can be set when add a new model

## How to determine the reward amount or refund amount (Stakeable)?

### Refund

1. Refund will be directly given back the remiaining if some requirements are met.

2. One requirement is at least (now - addedTime >= refundWaitTimeS)

3. Also (prediction == classification), which means if the prediction is not "right",
   we can not get any of the refund back. So we'd better give good data.

4. Being a good data simply means (prediction == classification) after updating the model
   using this data. (so some unique "good data" might be considered wrong)

5. The claimer of course has to be the original provider of the data.

### Reward

1. Reward can be also get directly if some requirements are met.

2. If the passedTime = (now - addedTime) is greater than or equal to the ownerClaimWaitTimeS
   and the reporter is the owner who deployed this model, then the remaining deposit (claimable amount)
   will be all given to the owner.

3. If the passedTime = (now - addedTime) is greater than or equal to the anyAddressClaimWaitTimeS
   then anyone can just get all the remaining deposit (see who is faster...)

4. If the passedTime is just greater then or equal to the refundWaitTimeS
   then the reward will be calculate based on how much contribution the reporter made before.
   so reward = initialDeposit * numGoodForReporter / totalGoodDataCount

5. Compared to the refund, the claimer can be anyone except the original provider.

## How to interact with the contracts?

1. Using web3.js...

## What happen when adding a new data?

1. When adding a new data (click the train button), the data sample will be immediately used to
   update the model and given to DataHandler to record the meta-data on the blockchain.

2. Next, the info of refund data will be updated (the last column info).
   - If the passedTime is less than refundWaitTimeS, then just show how long to wait.
   - If it is ok above and it can be refunded, then just show the button.
   - If it can not be refunded for some reasons including:
      1. Already been claimed before.
      2. The prediction is not matched with the label

     then just show related information about the reason.

   ```js
   if (hasEnoughTimePassed) {
      if (canAttemptRefund) {
         console.log('show the button');
      } else if (alreadyClaimed) {
         console.log('Already refunded or completely claimed.');
      } else if (classification !== prediction) {
         console.log('Classification does not match.')
      }
   } else {
      console.log('show the waiting time');
   }
   ```

3. In fact, at the fist step, the newly added data will be notify through the event,
   so that every node can get the data. then everyone will update their reward data list.
   The reward data list actually contains all the submitted sample, but you might not be able to
   get some reward from every data of course (in this case, only the bad data).

4. The info of the reward data list is updated: (actually it will check everytime open the reward tab).
   - The fisrt two steps is the same as refund, checking the passedTime and the canAttemptRefund.
   - If canAttemptRefund is true, when clicking the button, the reward will be calculated
     following the principle metioned before.
   - If canAttemptRefund is not True, then see the possible reasons:
      1. This node does not have any previous contribution (numGoodForReporter === 0).
      2. Already claimed, in this case, get the reward already.
      3. The prediction is same as the label (the data is good data)

     then just show related information about the reason.

   ```js
   if (hasEnoughTimePassed) {
      if (canAttemptRefund) {
         console.log('show the button');
      } else if (this.state.numGood === 0 || this.state.numGood === undefined) {
         // this.state.numGood === numGoodForReporter of the node (reporter)
         console.log('Validate your own contributions first.');
      } else if (alreadyClaimed) {
         console.log('Already refunded or completely claimed.');
      } else if (classification === prediction) {
         console.log('Classification must be wrong for you to claim this.')
      }
   } else {
      console.log('show the waiting time');
   }
   ```

## What happen when someone added a bad sample then report it using another account?

1. It can be done in this case actually, but it will not get too much reward.
   Recall how to determine the reward amount, you need to make contributions to
   get the reward.

## When actually the report happen?

1. As mentioned in the question about what happen when adding a new data,
   we can say that each submitted data sample will be "reported" by every other nodes.
   So everyone is the reporter except the original provider.

2. since the data was added, it has been "reported".

3. In general, the "reported" data (every data) will be in the reward data list.
   However, not every data can "produce" actual reward (only bad data) and
   the reward amount varies from node to node ("reporter" to "reporter")
   according to how much contribution they have made.

4. Note that the actual report will be claimed only when the node click the "take reward" button.
   This action will update the meta-data of the sample such as **claimable amount (remaining deposit)**,
   **number of the total claims** and **if it is already claimed by the node clicking that button**

5. Overall, the report action is a virtual concept because it is passive instead of being initiative
   In other words, it is the CollaborativeTrainer that worked out if the data is good or not
   and if it i contributions befs bad data, every one who have made someore has the chance to
   get the reward util the claimable amount (remaining deposit) is 0.
   In this way, to get more reward every time there is bad data pop up, those good contributors
   will make the contribution as much as possible (if the accuracy of the model is ok).

## What happen when a sample data is reported by multiple reporters?

After the above analysis (if it is right), this is a meaningless question.
