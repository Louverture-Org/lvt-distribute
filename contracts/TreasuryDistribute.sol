// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types/EIP712.sol";
import "./library/Ownable.sol";
import "./library/SafeERC20.sol";
import "./library/AccessControl.sol";

contract TreasuryDistribute is Ownable, EIP712, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 private constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    mapping(address => bool) public UserClaim;

    constructor(address signer) EIP712("LVT", "1.0.0") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(SIGNER_ROLE, signer);
    }

    event UserClaimed(address indexed user, uint amount);

    function close() external onlyOwner { 
        selfdestruct(payable(msg.sender));
    }

    function _verify(
        bytes32 _digest, 
        bytes memory _signature
    ) private view returns (bool) {
        return hasRole(SIGNER_ROLE, ECDSA.recover(_digest, _signature));
    }

    function _hash(
        address _account, 
        uint256 _amount
    ) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("Claim(uint256 amount,address account)"),
            _amount,
            _account
        )));
    }

    function claim(uint amount, bytes calldata signature) external {
        require(amount > 0, "Invalid amount");
        address account = msg.sender;
        require(!UserClaim[account], "Already claimed");

        // checking merkle proof
        require(_verify(_hash(account, amount), signature), "Invalid signature");

        UserClaim[account] = true;
        payable(account).transfer(amount);

        emit UserClaimed(account, amount);
    }

    receive() external payable {}

    function withdrawAvax(address wallet) external onlyOwner {
        payable(wallet).transfer(address(this).balance);
    }

    function withdrawToken(address token, address wallet) external onlyOwner {
        IERC20(token).safeTransfer(wallet, IERC20(token).balanceOf(address(this)));
    }
}