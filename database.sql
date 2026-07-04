-- =========================
-- ENABLE UUID EXTENSION
-- =========================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================
-- 1. PRICELIST (SCD1)
-- =========================
CREATE TABLE PriceList (
    PriceListID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ownership VARCHAR(10) CHECK (ownership IN ('shared', 'private')) NOT NULL,
    service VARCHAR(100) NOT NULL,
    package VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    status VARCHAR(10) CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for filtering active services
CREATE INDEX idx_pricelist_status ON PriceList(status);

-- =========================
-- 2. CLIENTS (SCD1)
-- =========================
CREATE TABLE Clients (
    clientID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =========================
-- 3. USERS (AUTH / PROFILE)
-- =========================
CREATE TABLE Users (
    userID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clientID UUID UNIQUE REFERENCES Clients(clientID) ON DELETE CASCADE,
    profile_name VARCHAR(100),
    pincode_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =========================
-- 4. ORDERS (FACT TABLE)
-- =========================
CREATE TABLE Orders (
    orderID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clientID UUID REFERENCES Clients(clientID) ON DELETE CASCADE,
    PriceListID UUID REFERENCES PriceList(PriceListID),

    price_snapshot NUMERIC(10,2) NOT NULL,
    package_snapshot VARCHAR(100),
    service_snapshot VARCHAR(100),

    payment_status VARCHAR(10) CHECK (
        payment_status IN ('pending', 'approved', 'failed')
    ) DEFAULT 'pending',

    amount_paid NUMERIC(10,2) DEFAULT 0,

    created_at TIMESTAMP DEFAULT NOW(),
    approved_at TIMESTAMP
);

CREATE INDEX idx_orders_client ON Orders(clientID);
CREATE INDEX idx_orders_payment ON Orders(payment_status);

-- =========================
-- 5. ACCOUNTS (DELIVERY TABLE)
-- =========================
CREATE TABLE Accounts (
    accountID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    orderID UUID UNIQUE REFERENCES Orders(orderID) ON DELETE CASCADE,

    service VARCHAR(100) NOT NULL,
    ownership VARCHAR(10),
    package VARCHAR(100),

    email VARCHAR(120),
    password_hash TEXT NOT NULL,

    amt_paid NUMERIC(10,2) DEFAULT 0,

    sub_start DATE,
    sub_expiry DATE,

    sub_status VARCHAR(20) CHECK (
        sub_status IN ('active', 'pending_expiry', 'expired')
    ) DEFAULT 'active',

    assigned VARCHAR(5) CHECK (assigned IN ('yes', 'no')) DEFAULT 'no',

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_accounts_status ON Accounts(sub_status);

-- =========================
-- 6. SUBSCRIPTION HISTORY (TRACKING / SCD2)
-- =========================
CREATE TABLE SubscriptionHistory (
    subscriptionID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    accountID UUID REFERENCES Accounts(accountID) ON DELETE CASCADE,
    orderID UUID REFERENCES Orders(orderID) ON DELETE CASCADE,

    status VARCHAR(20) CHECK (
        status IN ('active', 'expired', 'paused')
    ) DEFAULT 'active',

    start_date DATE NOT NULL,
    end_date DATE,

    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subhistory_account ON SubscriptionHistory(accountID);

-- =========================
-- AUTO UPDATE TIMESTAMP FUNCTION
-- =========================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to PriceList
CREATE TRIGGER update_pricelist_updated_at
BEFORE UPDATE ON PriceList
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to Accounts
CREATE TRIGGER update_accounts_updated_at
BEFORE UPDATE ON Accounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();