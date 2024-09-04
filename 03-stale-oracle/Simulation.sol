// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface MoneyMarket {
    function supply(address asset, uint amount) external returns (uint);
    function borrow(address asset, uint amount) external returns (uint);
    function getSupplyBalance(address account, address asset) external view returns (uint);
    function getBorrowBalance(address account, address asset) external view returns (uint);
    function markets(address asset) external view returns (
        bool isSupported,
        uint256 blockNumber,
        address interestRateModel,
        uint256 totalSupply,
        uint256 supplyRateMantissa,
        uint256 supplyIndex,
        uint256 totalBorrows,
        uint256 borrowRateMantissa,
        uint256 borrowIndex
    );
}

contract CompoundV1BorrowTest is Test {
    address constant MONEY_MARKET = 0x3FDA67f7583380E67ef93072294a7fAc882FD7E7;
    address constant DAI = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    MoneyMarket moneyMarket = MoneyMarket(MONEY_MARKET);
    IERC20 dai = IERC20(DAI);
    IERC20 weth = IERC20(WETH);

    function setUp() public {
        vm.createSelectFork("mainnet", 7895899);
    }
    
    function testCompoundV1Borrow() public {
        // Deal DAI to this contract
        deal(DAI, address(this), 2000 * 1e18);

        console.log("Initial DAI balance:", dai.balanceOf(address(this)));
        console.log("Initial WETH balance:", weth.balanceOf(address(this)));

        // Approve and supply DAI to Compound v1
        dai.approve(MONEY_MARKET, type(uint256).max);
        uint256 supplyAmount = 1000 * 1e18; // 1000 DAI
        uint256 supplyResult = moneyMarket.supply(DAI, supplyAmount);
        console.log("Supply result:", supplyResult);

        // Check supply balance
        uint256 supplyBalance = moneyMarket.getSupplyBalance(address(this), DAI);
        console.log("DAI supply balance:", supplyBalance);

        // Get market info for DAI and WETH
        (bool daiSupported, , , uint256 daiTotalSupply, , , uint256 daiTotalBorrows, , ) = moneyMarket.markets(DAI);
        (bool wethSupported, , , uint256 wethTotalSupply, , , uint256 wethTotalBorrows, , ) = moneyMarket.markets(WETH);
        console.log("DAI market supported:", daiSupported);
        console.log("DAI total supply:", daiTotalSupply);
        console.log("DAI total borrows:", daiTotalBorrows);
        console.log("WETH market supported:", wethSupported);
        console.log("WETH total supply:", wethTotalSupply);
        console.log("WETH total borrows:", wethTotalBorrows);

        // Try to borrow WETH
        uint256 borrowAmount = 0.1 * 1e18; // 0.1 WETH
        uint256 borrowResult = moneyMarket.borrow(WETH, borrowAmount);
        console.log("Borrow result:", borrowResult);

        // Check balances after borrow
        console.log("DAI balance after borrow:", dai.balanceOf(address(this)));
        console.log("WETH balance after borrow:", weth.balanceOf(address(this)));
        console.log("WETH borrow balance:", moneyMarket.getBorrowBalance(address(this), WETH));

        // Assert statements to verify the borrow was successful
        assertEq(borrowResult, 0, "Borrow should succeed with error code 0");
        assertGt(weth.balanceOf(address(this)), 0, "WETH balance should be greater than 0 after borrowing");
    }
    receive() external payable{

    }
}