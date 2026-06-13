import { DownloadCta } from '@widgets/landing/download-cta'
import { FeatureList } from '@widgets/landing/feature-list'
import { Hero } from '@widgets/landing/hero'
import { ShortcutList } from '@widgets/landing/shortcut-list'
import { SiteFooter } from '@widgets/landing/site-footer'
import { SiteHeader } from '@widgets/landing/site-header'

const Page = () => (
    <>
        <SiteHeader />
        <main className='mx-auto max-w-5xl px-4 pb-10'>
            <Hero />
            <FeatureList />
            <ShortcutList />
            <DownloadCta />
        </main>
        <SiteFooter />
    </>
)

export default Page
