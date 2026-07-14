import type { Config } from 'tailwindcss';

export default {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        brand: '#1A5C2A',
        accent: '#F9A825',
      },
    },
  },
  plugins: [],
} satisfies Config;
