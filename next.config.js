/** @type {import('next').NextConfig} */
const nextConfig = {
  // config options here
  turbopack: {}
};

const withPWA = require('next-pwa')({
  dest: 'public',
  disable: process.env.NODE_ENV === 'development',
});

module.exports = withPWA(nextConfig);
