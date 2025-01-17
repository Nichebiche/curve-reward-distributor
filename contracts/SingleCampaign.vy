#pragma version 0.3.10
"""
@title SingleCampaign
@author martinkrung for curve.fi
@license MIT
@notice Distributes variable rewards for one gauge through RewardManager
"""

interface RewardManager:
    def send_reward_token(_receiving_gauge: address, _amount: uint256): nonpayable

# State Variables
managers: public(DynArray[address, 3])  # Changed from owner to managers
reward_manager_address: public(address)
receiving_gauge: public(address)
min_epoch_duration: public(uint256)

is_setup_complete: public(bool)
is_reward_epochs_set: public(bool)

reward_epochs: public(DynArray[uint256, 52])  # Storing reward amounts
last_reward_distribution_time: public(uint256)
have_rewards_started: public(bool)

WEEK: public(constant(uint256)) = 7 * 24 * 60 * 60  # 1 week in seconds
VERSION: public(constant(String[8])) = "0.9.0"
DISTRIBUTION_BUFFER: public(constant(uint256)) = 2 * 60 * 60  # 2 hour window for early distribution, max divation is 2.7%

# Events

event SetupCompleted:
    reward_manager_address: address
    receiving_gauge: address
    min_epoch_duration: uint256
    timestamp: uint256

event RewardEpochsSet:
    reward_epochs: DynArray[uint256, 52]
    timestamp: uint256

event RewardDistributed:
    reward_amount: uint256
    remaining_reward_epochs: uint256
    timestamp: uint256


@external
def __init__(_managers: DynArray[address, 3]):
    """
    @notice Initialize the contract with managers
    @param _managers List of manager addresses that can control the contract
    """
    self.managers = _managers
    self.min_epoch_duration = WEEK

@external
def setup(_reward_manager_address: address, _receiving_gauge: address, _min_epoch_duration: uint256):
    """
    @notice Set the reward manager and receiver addresses (can only be set once)
    @param _reward_manager_address Address of the RewardManager contract
    @param _receiving_gauge Address of the RewardReceiver contract
    @param _min_epoch_duration Minimum epoch duration in seconds
    """
    assert msg.sender in self.managers, "only managers can call this function"
    assert not self.is_setup_complete, "Setup already completed"
    assert 3 * WEEK / 7 <= _min_epoch_duration and _min_epoch_duration <= WEEK  * 4 * 12, 'epoch duration must be between 3 days and a year'
    
    self.reward_manager_address = _reward_manager_address
    self.receiving_gauge = _receiving_gauge
    self.min_epoch_duration = _min_epoch_duration

    self.is_setup_complete = True

    log SetupCompleted(_reward_manager_address, _receiving_gauge, _min_epoch_duration, block.timestamp)


@external
def set_reward_epochs(_reward_epochs: DynArray[uint256, 52]):
    """
    @notice  Set the reward epochs in reverse order: last value is the first to be distributed, first value is the last to be distributed
    @param _reward_epochs List of reward amounts ordered from first to last epoch
    """
    assert msg.sender in self.managers, "only managers can call this function"
    assert not self.is_reward_epochs_set, "Reward epochs can only be set once"
    assert len(_reward_epochs) > 0 and len(_reward_epochs) <= 52, "Must set between 1 and 52 epochs"
    
    self.reward_epochs = _reward_epochs
    self.is_reward_epochs_set = True

    log RewardEpochsSet(_reward_epochs, block.timestamp)    


@external
def distribute_reward():
    """
    @notice Distribute rewards for the current epoch if conditions are met
    """
    # assert msg.sender in self.managers, "only managers can call this function"
    assert self.is_setup_complete, "Setup not completed"
    assert self.is_reward_epochs_set, "Reward epochs not set"
    assert len(self.reward_epochs) > 0, "No remaining reward epochs"

    # Check if minimum time has passed since last distribution if not first distribution
    if self.have_rewards_started:
        assert block.timestamp + DISTRIBUTION_BUFFER >= self.last_reward_distribution_time + self.min_epoch_duration, "Minimum time between distributions not met"
    
    # Get the reward amount for the current epoch (last in array)  
    current_reward_amount: uint256 = self.reward_epochs.pop()
    
    # Update last distribution time and mark rewards as started
    self.last_reward_distribution_time = block.timestamp
    self.have_rewards_started = True
    
    # Call reward manager to send reward
    RewardManager(self.reward_manager_address).send_reward_token(self.receiving_gauge, current_reward_amount)
    
    log RewardDistributed(
        current_reward_amount,
        len(self.reward_epochs),  # Remaining reward epochs
        block.timestamp
    )
    

@external
@view
def get_next_epoch_info() -> (uint256, uint256):
    """
    @notice Get information about the next epoch to be distributed
    @return tuple(
        next_reward_amount: Amount for next epoch,
        seconds_until_next_distribution: Seconds left until next distribution is allowed
    )
    """
    assert len(self.reward_epochs) > 0, "No remaining reward epochs"
    
    seconds_until_next_distribution: uint256 = 0
    if self.have_rewards_started:
        if block.timestamp < self.last_reward_distribution_time + self.min_epoch_duration:
            seconds_until_next_distribution = self.last_reward_distribution_time + self.min_epoch_duration - block.timestamp
    
    return (
        self.reward_epochs[len(self.reward_epochs) - 1],  # Next reward amount to distribute (last element)
        seconds_until_next_distribution
    )


@external
@view
def get_all_epochs() -> DynArray[uint256, 52]:
    """
    @notice Get all remaining reward epochs
    @return DynArray[uint256, 52] Array containing all remaining reward epoch amounts
    """
    return self.reward_epochs

@external
@view
def get_all_managers() -> DynArray[address, 3]:
    """
    @notice Get all managers
    @return DynArray[address, 3] Array containing all managers
    """
    return self.managers

@external
@view
def get_number_of_remaining_epochs() -> uint256:
    """
    @notice Get the number of remaining reward epochs
    @return uint256 Remaining number of reward epochs
    """
    return len(self.reward_epochs)
