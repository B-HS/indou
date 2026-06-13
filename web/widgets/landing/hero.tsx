import { Reveal } from '@features/landing/reveal'
import { SwitcherPreview } from '@features/landing/switcher-preview'
import { asset, REPO_URL, RELEASE_URL } from '@lib/constants'
import { Button } from '@ui/button'
import { Kbd } from '@ui/kbd'

export const Hero = () => (
    <section id='top' className='flex flex-col items-center gap-6 pt-16 pb-12 text-center sm:pt-24'>
        <Reveal>
            <img src={asset('/icon.svg')} width={88} height={88} alt='Indou' className='drop-shadow-sm' />
        </Reveal>
        <Reveal delay={0.06} className='flex flex-col items-center gap-4'>
            <h1 className='text-4xl font-extrabold tracking-tight lg:text-5xl'>Indou</h1>
            <p className='max-w-xl text-lg leading-7 text-muted-foreground'>
                A fast, modern macOS window switcher. Hold the modifier, glance at every window across every Space, release to jump — the
                capable, free alternative to AltTab.
            </p>
        </Reveal>
        <Reveal delay={0.12} className='flex items-center gap-2 text-sm text-muted-foreground'>
            <Kbd>⌥</Kbd>
            <Kbd>⇥</Kbd>
            <span>to cycle · release to focus</span>
        </Reveal>
        <Reveal delay={0.18} className='flex flex-wrap items-center justify-center gap-3 pt-1'>
            <Button asChild size='lg'>
                <a href={RELEASE_URL} target='_blank' rel='noopener'>
                    Download for macOS
                </a>
            </Button>
            <Button asChild size='lg' variant='outline'>
                <a href={REPO_URL} target='_blank' rel='noopener'>
                    View source
                </a>
            </Button>
        </Reveal>
        <Reveal delay={0.24}>
            <p className='font-mono text-2xs tracking-wide text-muted-foreground'>macOS 26 · Apple Silicon &amp; Intel · Free &amp; open source</p>
        </Reveal>
        <Reveal delay={0.3} className='w-full flex justify-center'>
            <SwitcherPreview />
        </Reveal>
    </section>
)
