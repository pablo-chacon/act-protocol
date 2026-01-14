// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ActToken is ERC20 {
    address public immutable core;

    error TransfersDisabled();
    error OnlyCore();

    constructor(address _core) ERC20("ACT Service Handle", "ACT") {
        core = _core;
    }

    modifier onlyCore() {
        if (msg.sender != core) revert OnlyCore();
        _;
    }

    // 1 token == 1 service instance handle (18 decimals by ERC20 default)
    function mint(address to) external onlyCore {
        _mint(to, 1e18);
    }

    function burn(address from) external onlyCore {
        _burn(from, 1e18);
    }

    // block transfers, allow only mint (from == 0) and burn (to == 0)
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) revert TransfersDisabled();
        super._update(from, to, value);
    }
}
