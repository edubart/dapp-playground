local cartesi_rolling_machine = require("cartesi-testlib.rolling-machine")
local encode_utils = require("cartesi-testlib.encode-utils")
local lester = require("cartesi-testlib.lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

local ERC20_PORTAL_ADDRESS = "0x4340ac4FcdFC5eF8d34930C96BBac2Af1301DF40"
local ERC20_CONTRACT_ADDRESS = "0xc6e7DF5E7b4f2A278906862b61205850344D4e7d"
local ERC20_WITHDRAW_ADDRESS = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
local ERC20_ALICE_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
local MACHINE_STORED_DIR = "snapshot"
local MACHINE_RUNTIME_CONFIG = {
    skip_root_hash_check = true,
    skip_version_check = true,
}
local REMOTE_PROTOCOL = arg[1] or "jsonrpc"

local HONEYPOT_STATUS_SUCCESS = string.char(0)
local HONEYPOT_STATUS_DEPOSIT_TRANSFER_FAILED = string.char(1)
local HONEYPOT_STATUS_DEPOSIT_INVALID_CONTRACT = string.char(2)
local HONEYPOT_STATUS_DEPOSIT_BALANCE_OVERFLOW = string.char(3)
local HONEYPOT_STATUS_WITHDRAW_NO_FUNDS = string.char(4)

describe("honeypot", function()
    local rolling_machine <close> = cartesi_rolling_machine(MACHINE_STORED_DIR, MACHINE_RUNTIME_CONFIG, REMOTE_PROTOCOL)

    it("should accept first deposit", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 1,
            }),
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_SUCCESS } },
        }
        expect.equal(res, expected_res)
    end)

    it("should accept second deposit", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 2,
            }),
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_SUCCESS } },
        }
        expect.equal(res, expected_res)
    end)

    it("should accept third deposit with 0 amount", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 0,
            }),
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_SUCCESS } },
        }
        expect.equal(res, expected_res)
    end)

    it("should reject deposit with transfer failed status", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = false,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 3,
            }),
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_DEPOSIT_TRANSFER_FAILED } },
        }
        expect.equal(res, expected_res)
    end)

    it("should reject deposit with invalid contract address", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_ALICE_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 3,
            }),
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_DEPOSIT_INVALID_CONTRACT } },
        }
        expect.equal(res, expected_res)
    end)

    it("should reject deposit with invalid sender address", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_ALICE_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 3,
            }),
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = {},
        }
        expect.equal(res, expected_res)
    end)

    it("should reject deposit with invalid payload length", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_PORTAL_ADDRESS,
            },
            payload = encode_utils.encode_erc20_deposit({
                successful = true,
                contract_address = ERC20_CONTRACT_ADDRESS,
                sender_address = ERC20_ALICE_ADDRESS,
                amount = 2,
                extra_data = "\x00",
            }),
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = {},
        }
        expect.equal(res, expected_res)
    end)

    it("should accept balance inspect", function()
        local res = rolling_machine:inspect_state({
            metadata = {
                msg_sender = ERC20_ALICE_ADDRESS,
            },
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {},
            notices = {},
            reports = { { payload = encode_utils.encode_be256(3) } },
        }
        expect.equal(res, expected_res)
    end)

    it("should reject withdraw with invalid payload length", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_WITHDRAW_ADDRESS,
            },
            payload = "\x00",
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = {},
        }
        expect.equal(res, expected_res)
    end)

    it("should accept withdraw when there is funds", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_WITHDRAW_ADDRESS,
            },
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {
                {
                    address = encode_utils.encode_erc20_address(ERC20_CONTRACT_ADDRESS),
                    payload = encode_utils.encode_erc20_transfer_voucher({
                        destination_address = ERC20_WITHDRAW_ADDRESS,
                        amount = 3,
                    }),
                },
            },
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_SUCCESS } },
        }
        expect.equal(res, expected_res)
    end)

    it("should reject withdraw when there is no funds", function()
        local res = rolling_machine:advance_state({
            metadata = {
                msg_sender = ERC20_WITHDRAW_ADDRESS,
            },
        }, true)
        local expected_res = {
            status = "rejected",
            vouchers = {},
            notices = {},
            reports = { { payload = HONEYPOT_STATUS_WITHDRAW_NO_FUNDS } },
        }
        expect.equal(res, expected_res)
    end)

    it("should accept inspect when there is no funds", function()
        local res = rolling_machine:inspect_state({
            metadata = {
                msg_sender = ERC20_ALICE_ADDRESS,
            },
        }, true)
        local expected_res = {
            status = "accepted",
            vouchers = {},
            notices = {},
            reports = { { payload = encode_utils.encode_be256(0) } },
        }
        expect.equal(res, expected_res)
    end)
end)
