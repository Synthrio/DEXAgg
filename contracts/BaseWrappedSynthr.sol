// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Inheritance
import "../interfaces/IERC20.sol";
import "./ExternWrappedStateToken.sol";
import "../MixinResolver.sol";
import "../Proxyable.sol";
// Internal references
import "../interfaces/ISynth.sol";
import "../interfaces/ISystemStatus.sol";
import "../interfaces/IExchanger.sol";
import "../interfaces/IExchangeRates.sol";
import "../interfaces/IExchangeAgent.sol";
import "../interfaces/IIssuer.sol";
import "../interfaces/ILiquidator.sol";
import "../interfaces/ILiquidatorRewards.sol";
import "../interfaces/ISynthrBridge.sol";
import "../interfaces/ISynthrAggregator.sol";
import "../libraries/TransferHelper.sol";
import "../SafeDecimalMath.sol";

contract BaseWrappedSynthr is Proxyable, MixinResolver {
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;
    // ========== STATE VARIABLES ==========

    // Available Synths which can be used with the system
    bytes32 public constant sUSD = "sUSD";

    ExternWrappedStateToken extTokenState;

    address internal constant NULL_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ========== ADDRESS RESOLVER CONFIGURATION ==========
    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
    bytes32 private constant CONTRACT_EXCHANGER = "Exchanger";
    bytes32 private constant CONTRACT_ISSUER = "Issuer";
    bytes32 private constant CONTRACT_LIQUIDATOR = "Liquidator";
    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 private constant CONTRACT_EXCHANGE_AGENT = "ExchangeAgent";
    bytes32 private constant CONTRACT_LIQUIDATOR_REWARDS = "LiquidatorRewards";
    bytes32 private constant CONTRACT_SYNTHRBRIDGE = "SynthrBridge";
    bytes32 private constant CONTRACT_SYNTHR_AGGREGATOR = "SynthrAggregator";

    // ========== CONSTRUCTOR ==========
    constructor(
        address payable _proxy,
        ExternWrappedStateToken _extTokenState,
        address _owner,
        address _resolver
    ) MixinResolver(_resolver) Proxyable(_owner, _proxy) {
        extTokenState = _extTokenState;
    }

    // ========== VIEWS ==========

    // Note: use public visibility so that it can be invoked in a subclass
    function resolverAddressesRequired() public pure override returns (bytes32[] memory addresses) {
        addresses = new bytes32[](9);
        addresses[0] = CONTRACT_SYSTEMSTATUS;
        addresses[1] = CONTRACT_EXCHANGER;
        addresses[2] = CONTRACT_ISSUER;
        addresses[3] = CONTRACT_LIQUIDATOR;
        addresses[4] = CONTRACT_EXRATES;
        addresses[5] = CONTRACT_LIQUIDATOR_REWARDS;
        addresses[6] = CONTRACT_SYNTHRBRIDGE;
        addresses[7] = CONTRACT_SYNTHR_AGGREGATOR;
        addresses[8] = CONTRACT_EXCHANGE_AGENT;
    }

    function systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

    function exchanger() internal view returns (IExchanger) {
        return IExchanger(requireAndGetAddress(CONTRACT_EXCHANGER));
    }

    function exchangeRates() internal view returns (IExchangeRates) {
        return IExchangeRates(requireAndGetAddress(CONTRACT_EXRATES));
    }

    function exchangeAgent() internal view returns (IExchangeAgent) {
        return IExchangeAgent(requireAndGetAddress(CONTRACT_EXCHANGE_AGENT));
    }

    function issuer() internal view returns (IIssuer) {
        return IIssuer(requireAndGetAddress(CONTRACT_ISSUER));
    }

    function liquidatorRewards() internal view returns (ILiquidatorRewards) {
        return ILiquidatorRewards(requireAndGetAddress(CONTRACT_LIQUIDATOR_REWARDS));
    }

    function liquidator() internal view returns (ILiquidator) {
        return ILiquidator(requireAndGetAddress(CONTRACT_LIQUIDATOR));
    }

    function isWaitingPeriod(bytes32 currencyKey) external view returns (bool) {
        return exchanger().maxSecsLeftInWaitingPeriod(messageSender, currencyKey) > 0;
    }

    function synthrBridge() internal view returns (ISynthrBridge) {
        return ISynthrBridge(requireAndGetAddress(CONTRACT_SYNTHRBRIDGE));
    }

    function synthrAggregator() internal view returns (ISynthrAggregator) {
        return ISynthrAggregator(requireAndGetAddress(CONTRACT_SYNTHR_AGGREGATOR));
    }

    function getAvailableCollaterals() external view returns (bytes32[] memory) {
        return extTokenState.getAvailableCollaterals();
    }

    function name() external view returns (string memory) {
        return extTokenState.name();
    }

    function symbol() external view returns (string memory) {
        return extTokenState.symbol();
    }

    function decimals() external view returns (uint256) {
        return extTokenState.decimals();
    }

    function collateralCurrency(bytes32 _collateralKey) external view returns (address) {
        return extTokenState.collateralCurrency(_collateralKey);
    }

    // ========== MUTATIVE FUNCTIONS ==========

    function exchange(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        uint16 destChainId
    )
        external
        payable
        exchangeActive(sourceCurrencyKey, destinationCurrencyKey)
        systemActive
        optionalProxy
        returns (uint256 amountReceived)
    {
        IExchanger.ExchangeArgs memory args = IExchanger.ExchangeArgs({
            fromAccount: messageSender,
            destAccount: messageSender,
            sourceCurrencyKey: sourceCurrencyKey,
            destCurrencyKey: destinationCurrencyKey,
            sourceAmount: sourceAmount,
            destAmount: 0,
            fee: 0,
            reclaimed: 0,
            refunded: 0,
            destChainId: destChainId
        });
        (amountReceived) = exchanger().exchange{value: msg.value}(messageSender, bytes32(0), args);
    }

    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode,
        uint16 destChainId
    )
        external
        payable
        exchangeActive(sourceCurrencyKey, destinationCurrencyKey)
        systemActive
        optionalProxy
        returns (uint256 amountReceived)
    {
        IExchanger.ExchangeArgs memory args = IExchanger.ExchangeArgs({
            fromAccount: messageSender,
            destAccount: messageSender,
            sourceCurrencyKey: sourceCurrencyKey,
            destCurrencyKey: destinationCurrencyKey,
            sourceAmount: sourceAmount,
            destAmount: 0,
            fee: 0,
            reclaimed: 0,
            refunded: 0,
            destChainId: destChainId
        });
        (amountReceived) = exchanger().exchange{value: msg.value}(rewardAddress, trackingCode, args);
    }

    function burnSynths(uint256 amount, bytes32 synthKey) external payable issuanceActive systemActive optionalProxy {
        (uint256 synthAmount, uint256 debtShare, uint256 reclaimed, uint256 refunded) = issuer().burnSynths(
            messageSender,
            synthKey,
            amount
        );
        synthrBridge().sendBurn{value: msg.value}(messageSender, synthKey, synthAmount, debtShare, reclaimed, refunded, false);
        liquidatorRewards().updateEntry(messageSender);
    }

    function burnSynthsToTarget(bytes32 synthKey) external payable issuanceActive systemActive optionalProxy {
        (uint256 synthAmount, uint256 debtShare, uint256 reclaimed, uint256 refunded) = issuer().burnSynthsToTarget(
            messageSender,
            synthKey
        );
        synthrBridge().sendBurn{value: msg.value}(messageSender, synthKey, synthAmount, debtShare, reclaimed, refunded, true);
        liquidatorRewards().updateEntry(messageSender);
    }

    function collateralTransfer(
        address _to,
        bytes32 _collateralKey,
        uint256 _usdAmount
    ) public systemActive optionalProxy returns (bool, uint256) {
        require(extTokenState.collateralCurrency(_collateralKey) != address(0), "");
        (uint256 collateralRate, ) = exchangeRates().rateAndInvalid(_collateralKey);
        uint256 collateralAmount = _usdAmount.divideDecimalRound(collateralRate);
        uint256 synthAmountToLiquidate;
        if (extTokenState.collateralCurrency(_collateralKey) == NULL_ADDRESS) {
            extTokenState.withdrawCollateral(address(exchangeAgent()), _collateralKey, collateralAmount);
            synthAmountToLiquidate = exchangeAgent().swapETHToSYNTH(collateralAmount, _to);
        } else {
            extTokenState.withdrawCollateral(address(this), _collateralKey, collateralAmount);
            if (
                IERC20(extTokenState.collateralCurrency(_collateralKey)).allowance(address(this), address(exchangeAgent())) == 0
            ) {
                TransferHelper.safeApprove(
                    extTokenState.collateralCurrency(_collateralKey),
                    address(exchangeAgent()),
                    type(uint256).max
                );
            }
            synthAmountToLiquidate = exchangeAgent().swapTokenToSYNTH(
                extTokenState.collateralCurrency(_collateralKey),
                collateralAmount,
                _to
            );
        }
        return (true, synthAmountToLiquidate);
    }

    /// @notice Force liquidate a delinquent account and distribute the redeemed synth rewards amongst the appropriate recipients.
    /// @dev The collateral transfers will revert if the amount to send is more than balanceOf account (i.e. due to escrowed balance).
    function liquidateDelinquentAccount(address account, bytes32 collateralKey)
        external
        payable
        systemActive
        optionalProxy
        returns (bool)
    {
        (uint256 totalRedeemed, uint256 amountLiquidated, uint256 sharesToRemove) = issuer().liquidateAccount(
            account,
            collateralKey,
            false
        );

        emitAccountLiquidated(account, totalRedeemed, amountLiquidated, messageSender);

        if (totalRedeemed > 0) {
            uint256 stakerRewards; // The amount of rewards to be sent to the LiquidatorRewards contract.
            // Check if the total amount of redeemed collateral is enough to payout the liquidation rewards.
            if (totalRedeemed > liquidator().flagReward().add(liquidator().liquidateReward())) {
                // Transfer the flagReward to the account who flagged this account for liquidation.
                address flagger = liquidator().getLiquidationCallerForAccount(account);
                (bool flagRewardTransferSucceeded, ) = collateralTransfer(flagger, collateralKey, liquidator().flagReward());
                require(flagRewardTransferSucceeded, "Flag reward transfer did not succeed.");

                // Transfer the liquidateReward to liquidator (the account who invoked this liquidation).
                // bool liquidateRewardTransferSucceeded = _transferByProxy(account, messageSender, liquidateReward);
                (bool liquidateRewardTransferSucceeded, ) = collateralTransfer(
                    messageSender,
                    collateralKey,
                    liquidator().liquidateReward()
                );
                require(liquidateRewardTransferSucceeded, "Liquidate reward transfer did not succeed.");

                // The remaining collateral to be sent to the LiquidatorRewards contract.
                stakerRewards = totalRedeemed.sub(liquidator().flagReward().add(liquidator().liquidateReward()));
            } else {
                /* If the total amount of redeemed collateral is greater than zero 
                but is less than the sum of the flag & liquidate rewards,
                then just send all of the collateral to the LiquidatorRewards contract. */
                stakerRewards = totalRedeemed;
            }

            (bool liquidatorRewardTransferSucceeded, uint256 synthAmountLiquidated) = collateralTransfer(
                address(liquidatorRewards()),
                collateralKey,
                stakerRewards
            );
            require(liquidatorRewardTransferSucceeded, "Transfer to LiquidatorRewards failed.");

            // Inform the LiquidatorRewards contract about the incoming collateral rewards.
            (uint256 collateralRate, ) = exchangeRates().rateAndInvalid(collateralKey);
            uint256 collateralAmount = totalRedeemed.divideDecimalRound(collateralRate);

            _burn(account, collateralAmount, collateralKey);

            liquidatorRewards().updateEntry(account);
            synthrBridge().sendLiquidate{value: msg.value}(
                account,
                collateralKey,
                collateralAmount,
                sharesToRemove,
                liquidatorRewards().rewardsToIncrease(sharesToRemove, synthAmountLiquidated)
            );
            liquidatorRewards().notifyRewardAmount(synthAmountLiquidated);

            return true;
        } else {
            // In this unlikely case, the total redeemed collateral is not greater than zero so don't perform any transfers.
            return false;
        }
    }

    /// @notice Allows an account to self-liquidate anytime its c-ratio is below the target issuance ratio.
    function liquidateSelf(bytes32 collateralKey) external payable systemActive optionalProxy returns (bool) {
        // Self liquidate the account (`isSelfLiquidation` flag must be set to `true`).
        (uint256 totalRedeemed, uint256 amountLiquidated, uint256 sharesToRemove) = issuer().liquidateAccount(
            messageSender,
            collateralKey,
            true
        );

        emitAccountLiquidated(messageSender, totalRedeemed, amountLiquidated, messageSender);

        // Transfer the redeemed collateral to the LiquidatorRewards contract.
        // Reverts if amount to redeem is more than balanceOf account (i.e. due to escrowed balance).
        (bool success, uint256 synthAmountLiquidated) = collateralTransfer(
            address(liquidatorRewards()),
            collateralKey,
            totalRedeemed
        );
        require(success, "Transfer to LiquidatorRewards failed.");

        // Inform the LiquidatorRewards contract about the incoming collateral rewards.
        (uint256 collateralRate, ) = exchangeRates().rateAndInvalid(collateralKey);
        uint256 collateralAmount = totalRedeemed.divideDecimalRound(collateralRate);

        _burn(messageSender, collateralAmount, collateralKey);

        liquidatorRewards().updateEntry(messageSender);
        synthrBridge().sendLiquidate{value: msg.value}(
            messageSender,
            collateralKey,
            collateralAmount,
            sharesToRemove,
            liquidatorRewards().rewardsToIncrease(sharesToRemove, synthAmountLiquidated)
        );
        liquidatorRewards().notifyRewardAmount(synthAmountLiquidated);
        return success;
    }

    bool public restituted = false;

    /**
     * @notice Once off function for SIP-239 to recover unallocated collateral rewards
     * due to an initialization issue in the LiquidatorRewards contract deployed in SIP-148.
     * @param _amount The amount of collateral to be recovered and distributed to the rightful owners
     */
    function initializeLiquidatorRewardsRestitution(uint256 _amount) external onlyOwner {
        if (!restituted) {
            restituted = true;
            bool success = liquidatorRewards().rewardRestitution(owner, _amount);
            // bool success = _transferByProxy(address(liquidatorRewards()), owner, amount);
            require(success, "restitution transfer failed");
        }
    }

    function _mint(
        address _to,
        uint256 _collateralAmount,
        bytes32 _collateralKey
    ) internal returns (bool) {
        emitTransfer(address(0), _to, _collateralAmount);

        // Increase total supply by minted amount
        extTokenState.increaseCollateral(_to, _collateralKey, _collateralAmount);

        return true;
    }

    function _burn(
        address _to,
        uint256 _collateralAmount,
        bytes32 _collateralKey
    ) internal returns (bool) {
        emitTransfer(_to, address(0), _collateralAmount);

        extTokenState.decreaseCollateral(_to, _collateralKey, _collateralAmount);
        return true;
    }

    // ========== MODIFIERS ==========

    modifier systemActive() {
        _systemActive();
        _;
    }

    function _systemActive() private view {
        systemStatus().requireSystemActive();
    }

    modifier issuanceActive() {
        _issuanceActive();
        _;
    }

    function _issuanceActive() private view {
        systemStatus().requireIssuanceActive();
    }

    modifier exchangeActive(bytes32 src, bytes32 dest) {
        _exchangeActive(src, dest);
        _;
    }

    function _exchangeActive(bytes32 src, bytes32 dest) private view {
        systemStatus().requireExchangeBetweenSynthsAllowed(src, dest);
    }

    modifier onlyExchanger() {
        _onlyExchanger();
        _;
    }

    function _onlyExchanger() private view {
        require(msg.sender == address(exchanger()), "Only Exchanger can invoke this");
    }

    // ========== EVENTS ==========

    event AccountLiquidated(address indexed account, uint256 snxRedeemed, uint256 amountLiquidated, address liquidator);
    bytes32 internal constant ACCOUNTLIQUIDATED_SIG = keccak256("AccountLiquidated(address,uint256,uint256,address)");

    event Transfer(address indexed from, address indexed to, uint256 value);
    bytes32 internal constant TRANSFER_SIG = keccak256("Transfer(address,address,uint256)");

    function addressToBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function emitTransfer(
        address from,
        address to,
        uint256 value
    ) internal {
        proxy._emit(abi.encode(value), 3, TRANSFER_SIG, addressToBytes32(from), addressToBytes32(to), 0);
    }

    function emitAccountLiquidated(
        address account,
        uint256 snxRedeemed,
        uint256 amountLiquidated,
        address liquidator_
    ) internal {
        proxy._emit(
            abi.encode(snxRedeemed, amountLiquidated, liquidator_),
            2,
            ACCOUNTLIQUIDATED_SIG,
            addressToBytes32(account),
            0,
            0
        );
    }

    event SynthExchange(
        address indexed account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    );
    bytes32 internal constant SYNTH_EXCHANGE_SIG =
        keccak256("SynthExchange(address indexed,bytes32,uint256,bytes32,uint256,address)");

    function emitSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    ) external onlyExchanger {
        proxy._emit(
            abi.encode(fromCurrencyKey, fromAmount, toCurrencyKey, toAmount, toAddress),
            2,
            SYNTH_EXCHANGE_SIG,
            addressToBytes32(account),
            0,
            0
        );
    }

    event ExchangeTracking(bytes32 indexed trackingCode, bytes32 toCurrencyKey, uint256 toAmount, uint256 fee);
    bytes32 internal constant EXCHANGE_TRACKING_SIG = keccak256("ExchangeTracking(bytes32 indexed,bytes32,uint256,uint256)");

    function emitExchangeTracking(
        bytes32 trackingCode,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        uint256 fee
    ) external onlyExchanger {
        proxy._emit(abi.encode(toCurrencyKey, toAmount, fee), 2, EXCHANGE_TRACKING_SIG, trackingCode, 0, 0);
    }

    event ExchangeReclaim(address indexed account, bytes32 currencyKey, uint256 amount);
    bytes32 internal constant EXCHANGERECLAIM_SIG = keccak256("ExchangeReclaim(address indexed,bytes32,uint256)");

    function emitExchangeReclaim(
        address account,
        bytes32 currencyKey,
        uint256 amount
    ) external onlyExchanger {
        proxy._emit(abi.encode(currencyKey, amount), 2, EXCHANGERECLAIM_SIG, addressToBytes32(account), 0, 0);
    }

    event ExchangeRebate(address indexed account, bytes32 currencyKey, uint256 amount);
    bytes32 internal constant EXCHANGEREBATE_SIG = keccak256("ExchangeRebate(address indexed,bytes32,uint256)");

    function emitExchangeRebate(
        address account,
        bytes32 currencyKey,
        uint256 amount
    ) external onlyExchanger {
        proxy._emit(abi.encode(currencyKey, amount), 2, EXCHANGEREBATE_SIG, addressToBytes32(account), 0, 0);
    }

    receive() external payable {}
}