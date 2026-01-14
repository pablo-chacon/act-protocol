// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/ActCore.sol";
import "../contracts/ActEscrow.sol";
import "../contracts/ActToken.sol";

contract DeployACT is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address protocolTreasury = vm.envAddress("PROTOCOL_TREASURY");

        vm.startBroadcast(deployerKey);

        // Deploy core (this internally deploys escrow + token)
        ActCore core = new ActCore(protocolTreasury);

        vm.stopBroadcast();

        // --- Output ---

        console2.log("ACT_CORE=", address(core));
        console2.log("ACT_ESCROW=", address(core.escrow()));
        console2.log("ACT_TOKEN=", address(core.token()));
        console2.log("PROTOCOL_TREASURY=", protocolTreasury);
        console2.log("PROTOCOL_FEE_BPS=50");
    }
}
