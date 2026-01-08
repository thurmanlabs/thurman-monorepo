import { createConfig, http } from 'wagmi'
import { arcTestnet } from 'wagmi/chains'

export const wagmiConfig = createConfig({
  chains: [arcTestnet],
  transports: {
    [arcTestnet.id]: http(process.env.NEXT_PUBLIC_ARCTESTNET_RPC_URL as string),
  },
});

declare module 'wagmi' {
  interface Register {
    config: typeof wagmiConfig
  }
}
