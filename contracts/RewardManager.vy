#pragma version 0.3.10
"""
@title RewardManager
@author martinkrung for curve.fi
@license MIT
@notice reward manager contract who can deposit a fixed reward token to allowed gauges
"""

from vyper.interfaces import ERC20

interface LegacyGauge:
    def deposit_reward_token(_reward_token: address, _amount: uint256): nonpayable

interface Gauge:
    def deposit_reward_token(_reward_token: address, _amount: uint256, _epoch: uint256): nonpayable

WEEK: constant(uint256) = 7 * 24 * 60 * 60  # 1 week in seconds
VERSION: constant(String[8]) = "0.9.0"

managers: public(DynArray[address, 30])
reward_token: public(address)
receiving_gauges: public(DynArray[address, 20])
recovery_address: public(address)

event SentRewardToken:
    receiving_gauge: address
    reward_token: address
    amount: uint256
    _epoch: uint256
    timestamp: uint256


@external
def __init__(_managers: DynArray[address, 30], _reward_token: address, _receiving_gauges: DynArray[address, 20], _recovery_address: address):
    """
    @notice Contract constructor
    @param _managers set managers who can send reward token to gauges
    @param _reward_token set reward token address
    @param _receiving_gauges allowed gauges to receiver reward
    @param _recovery_address set recovery address
    """
    self.managers = _managers
    self.reward_token = _reward_token
    self.receiving_gauges = _receiving_gauges
    self.recovery_address = _recovery_address

@external
def send_reward_token(_receiving_gauge: address, _amount: uint256, _epoch: uint256 = WEEK):
    """
    @notice send reward token from contract to gauge
    @param _receiving_gauge gauges to receiver reward
    @param _amount The amount of reward token being sent
    @param _epoch The duration the rewards are distributed across in seconds. Between 3 days and a year, week by default
    """
    assert msg.sender in self.managers, 'only reward managers can call this function'
    assert _receiving_gauge in self.receiving_gauges, 'only reward receiver which are allowed'
    assert 3 * WEEK / 7 <= _epoch and _epoch <= WEEK * 4 * 12, 'epoch duration must be between 3 days and a year'
    assert ERC20(self.reward_token).approve(_receiving_gauge, _amount, default_return_value=True)
    # legacy gauges have no epoch parameter 
    # new deposit_reward_token has epoch parameter default to WEEK
    if _epoch == WEEK:
        LegacyGauge(_receiving_gauge).deposit_reward_token(self.reward_token, _amount)
    else:
        Gauge(_receiving_gauge).deposit_reward_token(self.reward_token, _amount, _epoch)

    log SentRewardToken(_receiving_gauge, self.reward_token, _amount, _epoch, block.timestamp)

@external
def recover_token(_token: address, _amount: uint256):
    """
    @notice recover wrong token from contract to recovery address
    @param _amount amount of the token to recover
    """
    assert msg.sender in self.managers, 'only reward managers can call this function'
    assert _amount > 0, 'amount must be greater than 0'

    assert ERC20(_token).transfer(self.recovery_address, _amount, default_return_value=True)

@external
@view
def get_all_managers() -> DynArray[address, 30]:
    """
    @notice Get all managers
    @return DynArray[address, 30] list containing all managers
    """
    return self.managers

@external
@view
def get_all_receiving_gauges() -> DynArray[address, 20]:
    """
    @notice Get all reward receivers
    @return DynArray[address, 20] list containing all reward receivers
    """
    return self.receiving_gauges