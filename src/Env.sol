// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract Env is Script {
	string path;

	mapping (uint => mapping (bytes => bytes)) private database;
	mapping (uint => mapping (bytes => bool)) private observed;
	bytes[] keys;
	uint id;

	uint constant private ALLOWED_CHARS = 0x7fffffe87fffffe23ff000000000400;
	uint constant private BASE = 0x7fffffe87fffffe03ff000000000000;
	uint constant private NEWLINE = 10;
	uint constant private EQUAL_SIGN = 61;

	error WrongFileFormat(uint position);

	constructor(string memory _path) {
		path = _path;
		optimizeDatabase();
	}

	function envAddress(string memory str) internal returns (address result) {
		read(false);
		bytes memory s = database[id][bytes(str)];

		uint lastBytes;
		assembly {
			lastBytes := and(mload(add(s, 2)), 0xffff)
		}
		require(lastBytes == 0x3078, string(abi.encodePacked("Wrong address format: ", s)));
		require(s.length == 42, string(abi.encodePacked("Wrong address length: ", s)));

		assembly {
			for {let i := 3} lt(i, 43) {i := add(i, 1)} {
				let char := and(mload(add(s, i)), 0xff)

				switch and(gt(char, 47), lt(char, 58)) 
				case 1 {
					char := sub(char, 48)
				}
				default {
					switch and(gt(char, 64), lt(char, 71))
					case 1 {
						char := sub(char, 55)
					}
					default {
						switch and(gt(char, 96), lt(char, 103))
						case 1 {
							char := sub(char, 87)
						}
						default {
							revert(0, 0)
						}
					}
				}

				result := or(shl(4, result), char)
			}
		}
	}

	function envString(string memory str) internal returns (string memory) {
		read(false);
		return string(database[id][bytes(str)]);
	}

	function setEnv(string memory key, string memory val) internal {
		database[id][bytes(key)] = bytes(val);
		vm.writeLine(path, string(abi.encodePacked(key, "=", val)));
		vm.closeFile(path);

		optimizeDatabase();
	}

	function optimizeDatabase() internal {
		bytes[] memory newKeys = new bytes[](0);
		keys = newKeys;

		read(true);

		vm.removeFile(path);
		uint length = keys.length;
		uint _id = id;
		for (uint i = 0; i < length; i++) {
			bytes memory key = keys[i];
			vm.writeLine(
				path,
				string(
					abi.encodePacked(
						key,
						"=",
						database[_id][key]
					)
				)
			);
		}
		vm.closeFile(path);
	}

	function read(bool addKeys) internal {
		id++;
		bytes memory data = bytes(vm.readFile(path));

		uint len = data.length;
		uint startKey = 0;
		uint endKey = type(uint).max;
		for (uint i = 0; i < len; i++) {
			uint char = uint(uint8(data[i]));
			if (!_inMask(char, ALLOWED_CHARS))
				revert WrongFileFormat(i);

			if (!_inMask(char, BASE)) {
				if (char == NEWLINE) {
					if (endKey == type(uint).max)
						revert WrongFileFormat(i);
					bytes memory key = _substring(data, startKey, endKey);
					if (addKeys && !observed[id][key]) {
						keys.push(key);
						observed[id][key] = true;
					}
					database[id][key] = _substring(data, endKey + 1, i);
					endKey = type(uint).max;
					startKey = i + 1;
				} else if (char == EQUAL_SIGN) {
					if (endKey != type(uint).max)
						revert WrongFileFormat(i);

					endKey = i;
				} else {
					assert(false); // panic
				}
			}
		}

		if (endKey != type(uint).max) {
			bytes memory key = _substring(data, startKey, endKey);
			if (addKeys && !observed[id][key]) {
				keys.push(key);
				observed[id][key] = true;
			}
			database[id][key] = _substring(data, endKey + 1, len);
		}
	}

	function _inMask(uint value, uint map) private pure returns (bool result) {
		assembly {
			result := and(shr(value, map), 1)
		}
	}

	function _substring(bytes memory str, uint start, uint end) private pure returns (bytes memory) {
		if (start == end)
			return "";
		
		uint len = end - start;
		
		bytes memory result = new bytes(len);

		assembly {
			let ptr := add(str, 32)
			let endptr := add(ptr, end)

			let resendptr := add(add(result, 32), len)

			for {} gt(len, 32) {len := sub(len, 32)} {
				mstore(sub(resendptr, len), mload(sub(endptr, len)))
			}

			let prev := mload(resendptr)
			mstore(sub(resendptr, len), mload(sub(endptr, len)))
			mstore(resendptr, prev)
		}

		return result;
	}
}
