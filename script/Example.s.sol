// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Env.sol";

string constant PATH = "data/.data";

contract Example is Env {
	constructor() Env(PATH) {}

    function run() public {
		string memory key = "MY_VAR_NAME";
		string memory value = envString(key);
        // console.log(value);
		setEnv(
			key,
			string(abi.encodePacked(value, "plus"))
		);
    }
}
