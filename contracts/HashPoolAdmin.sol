// SPDX-License-Identifier: UNLICENSED  

pragma solidity ^0.8.28;

import {HashPool} from './HashPool.sol';

contract HassPoolAdmin {
    address payable public contractOwner;
    mapping(uint => HashPool) pools;
}