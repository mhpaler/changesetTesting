import Link from 'next/link';
import useSWR from 'swr';
import useTranslation from 'next-translate/useTranslation';
import { CopyAndPaste } from '../components/CopyAndPaste';

const TopTaggers = () => {
  const { t } = useTranslation('common');
  const { data, error } = useSWR(
    `{
      taggers(first: 5, orderBy: tagCount, orderDirection: desc) {
        id
        tagCount
      }
    }`);

  return (
    <div className="w-full mx-auto">
      <Link href="/">
        <a className="flex justify-between border border-b-0 border-slate-900">
          <div>
            <h2 className="px-6 py-3 text-xs tracking-wider text-left text-black uppercase">{t('top-taggers')}</h2>
          </div>
          <div className="flex items-center pr-2">
            <svg className="inline-flex w-6 h-6 text-pink-600 hover:text-pink-700" fill="none" viewBox="0 0 24 24">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M17.25 15.25V6.75H8.75"></path>
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M17 7L6.75 17.25"></path>
            </svg>
          </div>
        </a>
      </Link>

      <div className="border divide-y border-slate-900 divide-slate-200">
        {/* TODO: update :any to use type */}
        {data && data.taggers.map((tagger: any) => (
          <div className="grid grid-flow-col grid-cols-2 px-6 py-4 space-x-4" key={tagger.id}>
            <div className="flex space-x-2">
              <div className="flex-grow overflow-hidden text-right text-pink-600 hover:text-pink-700 text-ellipsis whitespace-nowrap">
                <Link href={`/taggers/${tagger.id}`}>
                  <a className="text-pink-600 hover:text-pink-700">{tagger.id}</a>
                </Link>
              </div>
              <CopyAndPaste value={tagger.id} />
            </div>
            <div className="text-sm leading-6 text-right whitespace-nowrap text-slate-500">{t('tagged-count', { count: parseInt(tagger.tagCount) })}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

export { TopTaggers };
