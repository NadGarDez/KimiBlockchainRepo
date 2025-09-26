import { ethers } from 'hardhat';

function toHex(value: bigint): string {
  let hexString = value.toString(16);
  if (!hexString.startsWith('0x')) {
    hexString = '0x' + hexString;
  }
  return hexString;
}

async function main() {
  const [owner] = await ethers.getSigners();

  const recipientAddress1 = '0xE2c66BE6706512773ADc718664F4F26d10558192';
  const recipientAddress2 = '0x8A87Cf83aae619bBB54E039783CA3945748D7e42';

  const amountToFund = ethers.parseEther('10'); // 10 ETH

  console.log(
    `Fondeando ${amountToFund.toString()} WEI a ${recipientAddress1}...`,
  );
  await ethers.provider.send('hardhat_setBalance', [
    recipientAddress1,
    toHex(amountToFund),
  ]);
  console.log(`Saldo de ${recipientAddress1} actualizado.`);

  console.log(
    `Fondeando ${amountToFund.toString()} WEI a ${recipientAddress2}...`,
  );
  await ethers.provider.send('hardhat_setBalance', [
    recipientAddress2,
    toHex(amountToFund),
  ]);
  console.log(`Saldo de ${recipientAddress2} actualizado.`);

  // Opcional: Verifica el nuevo saldo
  //   const balance1 = await ethers.provider.getBalance(recipientAddress1);
  //   console.log(`Nuevo saldo de ${recipientAddress1}: ${ethers.formatEther(balance1)} ETH`);

  //   const balance2 = await ethers.provider.getBalance(recipientAddress2);
  //   console.log(`Nuevo saldo de ${recipientAddress2}: ${ethers.formatEther(balance2)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
