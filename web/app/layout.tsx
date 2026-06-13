import { VirtualScroll } from '@features/theme/virtual-scroll'
import { ThemeProvider } from '@lib/providers/theme-provider'
import { GoToTop } from '@widgets/layout/go-to-top'
import type { Metadata } from 'next'
import { FC, PropsWithChildren } from 'react'
import './globals.css'

const SITE_URL = 'https://b-hs.github.io/indou'

export const metadata: Metadata = {
    metadataBase: new URL(SITE_URL),
    title: 'Indou — a fast, modern macOS window switcher',
    description: 'Hold ⌥, press Tab, release. A free, open-source AltTab alternative for macOS 26.',
    openGraph: {
        type: 'website',
        siteName: 'Indou',
        title: 'Indou — macOS window switcher',
        description: 'Hold ⌥, press Tab, release. A fast, modern, free window switcher for macOS 26.',
        images: [`${SITE_URL}/icon-512.png`],
    },
    robots: { index: true, follow: true },
}

const Layout: FC<PropsWithChildren> = ({ children }) => (
    <html lang='en' suppressHydrationWarning>
        <body className='antialiased relative'>
            <ThemeProvider>{children}</ThemeProvider>
            <VirtualScroll />
            <GoToTop />
        </body>
    </html>
)

export default Layout
