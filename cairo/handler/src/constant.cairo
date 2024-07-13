pub mod TxStatus {
    pub const UNKNOW: u8 = 0;
    pub const PENDING: u8 = 1;
    pub const MINTED: u8 = 2;
    pub const BURNED: u8 = 3;
    pub const FAILED: u8 = 4;
}

pub mod ERC20Method {
    pub const UNKNOW: u8 = 0;
    pub const TRANSFER: u8 = 1;
    pub const APPROVE: u8 = 2;
    pub const TRANSFERFROM: u8 = 3;
    pub const MINT: u8 = 4;
    pub const BURN: u8 = 5;
}

pub mod CrossChainTxStatus{
    pub const UNKNOW: u8 = 0;
    pub const PENDING: u8 = 1;
    pub const MINTED: u8 = 2;
    pub const SETTLED: u8 = 3;
    pub const FAILED: u8 = 4;
}