import { ThemeToggle } from '@features/theme/theme-toggle'
import { asset, REPO_URL, RELEASE_URL } from '@lib/constants'
import { Button } from '@ui/button'
import { Github } from 'lucide-react'

export const SiteHeader = () => (
    <header className='sticky top-0 z-50 h-12 backdrop-blur-xs bg-background/50'>
        <div className='max-w-5xl mx-auto h-full px-4 flex items-center justify-between'>
            <a href='#top' className='flex items-center gap-2 text-lg font-extrabold tracking-tight'>
                <img src={asset('/icon.svg')} width={24} height={24} alt='' />
                Indou
            </a>
            <nav className='flex items-center gap-1 sm:gap-2'>
                <Button asChild variant='ghost' size='sm' className='hidden sm:inline-flex'>
                    <a href='#features'>Features</a>
                </Button>
                <Button asChild variant='ghost' size='icon' aria-label='GitHub'>
                    <a href={REPO_URL} target='_blank' rel='noopener'>
                        <Github />
                    </a>
                </Button>
                <ThemeToggle />
                <Button asChild size='sm'>
                    <a href={RELEASE_URL} target='_blank' rel='noopener'>
                        Download
                    </a>
                </Button>
            </nav>
        </div>
    </header>
)
