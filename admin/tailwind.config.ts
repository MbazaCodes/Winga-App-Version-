import type { Config } from 'tailwindcss';

export default {
  content: ['./src/app/**/*.{js,ts,jsx,tsx}', './src/components/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#1A5C2A',
        accent: '#F9A825',
        surface: '#F7F7F7',
      },
    },
  },
  plugins: [],
} satisfies Config;
