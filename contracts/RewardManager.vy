# @version 0.3.10
"""
@title RewardManager
@author martinkrung for curve.fi
@license MIT
@notice reward manager contract who can deposit a fixed reward token to allowed gauges
"""

from vyper.interfaces import ERC20

interface Gauge:
    def deposit_reward_token(_reward_token: address, _amount: uint256): nonpayable

managers: public(DynArray[address, 3])
reward_token: public(address)
reward_receivers: public(DynArray[address, 20])

# set epoch length for newer gauges
@external
def __init__(_managers: DynArray[address, 3], _reward_token: address, _reward_receivers: DynArray[address, 20]):
    """
    @notice Contract constructor
    @param _managers set managers who can deposit reward token
    @param _reward_token set reward token address
    @param _reward_receivers allowed gauges to receiver reward
    """
    self.managers = _managers
    self.reward_token = _reward_token
    self.reward_receivers = _reward_receivers

@external
def deposit_reward_token(_reward_receiver: address, _amount: uint256):
    
    assert msg.sender in self.managers, 'dev: only reward managers can call this function'

    assert _reward_receiver in self.reward_receivers, 'dev: only reward receiver which are allowed'

    # deposit reward token from sender to this contract
    assert ERC20(self.reward_token).transferFrom(msg.sender, self, _amount)

    assert ERC20(self.reward_token).approve(_reward_receiver, _amount)

    Gauge(_reward_receiver).deposit_reward_token(self.reward_token, _amount)

@external
def deposit_reward_token_from_contract(_reward_receiver: address, _amount: uint256):
    """
    @notice forward reward token from contract to gauge
    @param _reward_receiver gauges to receiver reward
    @param _amount amount of reward token to deposit
    """
    assert msg.sender in self.managers, 'dev: only reward managers can call this function'

    assert _reward_receiver in self.reward_receivers, 'dev: only reward receiver which are allowed'

    assert ERC20(self.reward_token).approve(_reward_receiver, _amount)

    Gauge(_reward_receiver).deposit_reward_token(self.reward_token, _amount)
