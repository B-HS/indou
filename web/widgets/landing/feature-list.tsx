import { Reveal } from '@features/landing/reveal'

const FEATURES = [
    { title: 'Custom shortcuts', desc: 'Record any modifier + key. Multiple trigger profiles — all windows, current app, and more.' },
    { title: 'Every real window', desc: 'ScreenCaptureKit + Accessibility across Spaces and displays, including minimized and fullscreen. Background-only apps stay out.' },
    { title: 'Grid navigation', desc: 'Tab to cycle, arrow or vim keys to roam the 2D grid, release to focus. Auto-scrolls to the selection.' },
    { title: 'Act on windows', desc: 'Close, minimize, fullscreen, or quit from the switcher. Drag-select or ⌘-click to act on many at once.' },
    { title: 'Instant search', desc: 'Six-tier fuzzy matching plus Korean initial-consonant (초성) search.' },
    { title: 'Smooth & quiet', desc: 'Toggleable 120 Hz transitions, a non-activating overlay that never steals focus, and full localization.' },
]

export const FeatureList = () => (
    <section id='features' className='py-16'>
        <Reveal className='flex flex-col gap-7'>
            <h2 className='text-2xl font-bold tracking-tight'>What it does</h2>
            <div className='flex flex-col'>
                {FEATURES.map((f) => (
                    <div key={f.title} className='flex flex-col gap-1 border-b border-border py-4 sm:flex-row sm:gap-6'>
                        <h3 className='text-base font-semibold sm:w-56 sm:shrink-0'>{f.title}</h3>
                        <p className='text-sm leading-7 text-muted-foreground sm:flex-1'>{f.desc}</p>
                    </div>
                ))}
            </div>
        </Reveal>
    </section>
)
