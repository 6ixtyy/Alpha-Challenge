// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// reverse of stale_6

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface UniswapV1 {
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256 tokens_bought);
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256 eth_bought);
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract StaleTest is Test {
    IERC20 public TUSD;
    UniswapV1 public uniswapV1Pool;
    IUniswapV2Router02 public uniswapV2Router;

    address constant UNISWAP_V1_POOL = 0x4F30E682D0541eAC91748bd38A648d759261b8f3;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        vm.createSelectFork("mainnet", 14058540); 
        TUSD = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
        uniswapV1Pool = UniswapV1(UNISWAP_V1_POOL);
        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        
        deal(address(this), 10 ether);
    }

    function testArbitrageSwap() public {
        logBalances("Before swap");

        // Swap ETH for TUSD on Uniswap V1
        uint256 tusdBought = uniswapV1Pool.ethToTokenSwapInput{value: 671578643201640554}(1, block.timestamp + 1);

        logBalances("After V1 swap");

        // Approve TUSD for Uniswap V2 Router
        TUSD.approve(address(uniswapV2Router), tusdBought);

        // Swap TUSD back to ETH on Uniswap V2
        address[] memory path = new address[](2);
        path[0] = address(TUSD);
        path[1] = WETH;

        uint256 minEthOut = 1; // Set a reasonable minimum amount
        uniswapV2Router.swapExactTokensForETH(
            tusdBought,
            minEthOut,
            path,
            address(this),
            block.timestamp + 1
        );

        logBalances("After V2 swap");
    }

    function logBalances(string memory stage) private view {
        console.log(stage);
        console.log("ETH balance:", address(this).balance );
        console.log("TUSD balance:", TUSD.balanceOf(address(this)) / 1e18);
        console.log("V1 ETH pool balance:", address(UNISWAP_V1_POOL).balance );
        console.log("V1 TUSD pool balance:", TUSD.balanceOf(UNISWAP_V1_POOL) / 1e18);
        console.log("--------------------");
    }

    receive() external payable {}
}