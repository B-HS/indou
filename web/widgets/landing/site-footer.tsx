import { REPO_URL } from '@lib/constants'

export const SiteFooter = () => (
    <footer className='border-t border-border'>
        <div className='mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-2 px-4 py-8 text-xs text-muted-foreground'>
            <span>Indou · MIT License</span>
            <a href={REPO_URL} target='_blank' rel='noopener' className='font-mono hover:text-foreground'>
                github.com/B-HS/indou
            </a>
        </div>
    </footer>
)
