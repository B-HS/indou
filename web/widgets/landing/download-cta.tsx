import { Reveal } from '@features/landing/reveal'
import { asset, RELEASE_URL } from '@lib/constants'
import { Button } from '@ui/button'

export const DownloadCta = () => (
    <Reveal className='flex justify-center py-16'>
        <div className='flex w-full max-w-xl flex-col items-center gap-4 rounded-xl border border-border bg-card p-10 text-center shadow-sm'>
            <img src={asset('/icon.svg')} width={64} height={64} alt='' />
            <h2 className='text-2xl font-bold tracking-tight'>Get Indou</h2>
            <p className='max-w-sm text-sm leading-7 text-muted-foreground'>
                Free and open source under MIT. Requires macOS 26 (Tahoe). Notarized &amp; signed — opens with no warning.
            </p>
            <Button asChild size='lg'>
                <a href={RELEASE_URL} target='_blank' rel='noopener'>
                    Download the latest release
                </a>
            </Button>
            <p className='text-2xs text-muted-foreground'>Grants on first launch: Accessibility (required) · Screen Recording (optional, for thumbnails)</p>
        </div>
    </Reveal>
)
