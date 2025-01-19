pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "./GoldPeggedToken.sol";

contract GoldPeggedTokenTest is Test {
    GoldPeggedToken public token;

    function setUp() public {
        token = new GoldPeggedToken("Gold Token", "GOLD", 1900); // Initial gold price: $1900/gram
    }

    function testInitialGoldPrice() public view {
        assertEq(token.goldPriceInUSD(), 1900);
    }

    function testMint() public {
        vm.startPrank(address(this));
        token.mint(address(this), 1); // Mint 1 gram of gold
        vm.stopPrank();

        assertEq(token.balanceOf(address(this)), token.GRAM_OF_GOLD);
    }

    function testBurn() public {
        vm.startPrank(address(this));
        token.mint(address(this), 1); 
        vm.stopPrank();

        vm.startPrank(address(this));
        token.burn(address(this), 1); 
        vm.stopPrank();

        assertEq(token.balanceOf(address(this)), 0);
    }

    function testSetGoldPrice() public {
        vm.startPrank(address(this));
        token.setGoldPriceInUSD(2000); 
        vm.stopPrank();

        assertEq(token.goldPriceInUSD(), 2000);
    }

    function testGoldValueOf() public {
        vm.startPrank(address(this));
        token.mint(address(this), 1); 
        vm.stopPrank();

        uint256 goldValue = token.goldValueOf(token.GRAM_OF_GOLD); 
        assertEq(goldValue, token.goldPriceInUSD()); 
    }
}
