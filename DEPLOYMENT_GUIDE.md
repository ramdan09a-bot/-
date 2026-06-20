# 📋 دليل نشر عقد AtomicSettlementHub الذكي

## 🔧 المتطلبات الأساسية

### 1. **البرامج المطلوبة**
```bash
# Hardhat - إطار عمل تطوير Ethereum
npm install --save-dev hardhat

# OpenZeppelin Contracts
npm install @openzeppelin/contracts

# ethers.js - مكتبة للتفاعل مع Ethereum
npm install ethers

# Dotenv - لحفظ المتغيرات الحساسة
npm install dotenv
```

### 2. **المحفظة والمفاتيح**
أنت بحاجة إلى:
- **عنوان المحفظة (Wallet Address)** - لنشر العقد
- **مفتاح خاص (Private Key)** - للتوقيع على المعاملات
- **Testnet ETH** - للرسوم (غير حقيقي)

---

## 🌐 الشبكات المدعومة

| الشبكة | الرمز | URL RPC | Block Explorer |
|-------|------|---------|-----------------|
| Ethereum Mainnet | ETH | `https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY` | https://etherscan.io |
| Sepolia Testnet | ETH | `https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY` | https://sepolia.etherscan.io |
| Polygon (Matic) | MATIC | `https://polygon-rpc.com` | https://polygonscan.com |
| Binance Smart Chain | BNB | `https://bsc-dataseed.binance.org` | https://bscscan.com |
| Arbitrum One | ARB | `https://arb1.arbitrum.io/rpc` | https://arbiscan.io |
| Optimism | OP | `https://mainnet.optimism.io` | https://optimistic.etherscan.io |

---

## 🚀 خطوات النشر

### الخطوة 1: إعداد المشروع
```bash
mkdir atomic-settlement
cd atomic-settlement
npm init -y
npm install --save-dev hardhat
npx hardhat init
```

### الخطوة 2: نسخ العقد
أنسخ `AtomicSettlementHub.sol` إلى:
```
contracts/AtomicSettlementHub.sol
```

### الخطوة 3: إعداد Hardhat Config
```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    bsc: {
      url: process.env.BSC_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    optimism: {
      url: process.env.OPTIMISM_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
```

### الخطوة 4: إعداد متغيرات البيئة
```bash
# أنشئ ملف .env
cat > .env << EOF
PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-rpc.com
BSC_RPC_URL=https://bsc-dataseed.binance.org
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
OPTIMISM_RPC_URL=https://mainnet.optimism.io
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
EOF
```

### الخطوة 5: كتابة سكريبت النشر
```javascript
// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  console.log("🚀 جاري نشر العقد الذكي...");

  // عنوان الرمز ERC20
  const TOKEN_ADDRESS = "0x..."; // استبدل بعنوان الرمز الحقيقي

  // نشر العقد
  const AtomicSettlementHub = await hre.ethers.getContractFactory(
    "AtomicSettlementHub"
  );
  
  const contract = await AtomicSettlementHub.deploy(TOKEN_ADDRESS);
  await contract.deployed();

  console.log("✅ تم نشر العقد على العنوان:", contract.address);
  console.log("📋 hash المعاملة:", contract.deployTransaction.hash);

  // انتظر بعض الكتل
  await contract.deployTransaction.wait(5);

  // تحقق من العقد على Etherscan
  console.log("🔍 جاري التحقق من العقد...");
  await verify(contract.address, [TOKEN_ADDRESS]);
}

async function verify(contractAddress, args) {
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    console.log("✅ تم التحقق من العقد بنجاح!");
  } catch (e) {
    if (e.message.includes("Already Verified")) {
      console.log("✅ العقد مُتحقق منه مسبقاً");
    } else {
      console.log("⚠️ خطأ في التحقق:", e);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### الخطوة 6: النشر على Sepolia Testnet
```bash
# اختبر أولاً
npx hardhat test

# ثم انشر على testnet
npx hardhat run scripts/deploy.js --network sepolia
```

### الخطوة 7: النشر على الشبكة الرئيسية (Mainnet)
```bash
# ⚠️ تأكد من وجود ETH كافي في محفظتك!
npx hardhat run scripts/deploy.js --network ethereum
```

---

## 💰 تقدير الرسوم

| الشبكة | الرسوم المتوقعة | الوقت |
|-------|-----------------|------|
| Ethereum Mainnet | 0.005-0.02 ETH | 1-2 دقيقة |
| Sepolia Testnet | مجاني | 20-30 ثانية |
| Polygon | < 1 MATIC | 2-5 دقائق |
| BSC | < 0.1 BNB | 1-2 دقيقة |

---

## 🔐 تأمين المفتاح الخاص

⚠️ **تحذير أمني مهم:**
```javascript
// ❌ لا تفعل هذا أبداً:
const privateKey = "12345..."; // في الكود!

// ✅ استخدم متغيرات البيئة دائماً:
const privateKey = process.env.PRIVATE_KEY;
```

---

## ✅ التحقق بعد النشر

```bash
# 1. تحقق من عنوان العقد
etherscan.io/address/YOUR_CONTRACT_ADDRESS

# 2. تفاعل مع العقد
npx hardhat run scripts/interact.js --network sepolia

# 3. اقرأ البيانات من العقد
npx hardhat run scripts/read.js --network sepolia
```

---

## 📞 الدعم والمساعدة

- **Alchemy Dashboard**: https://dashboard.alchemy.com
- **Etherscan API**: https://etherscan.io/apis
- **Hardhat Docs**: https://hardhat.org
- **OpenZeppelin Docs**: https://docs.openzeppelin.com

---

**هل تريد مساعدة في أي خطوة؟** 🤝
