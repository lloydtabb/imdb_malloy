
SHELL = bash
.ONESHELL:

all: principals.parquet titles.parquet names.parquet

# Rule to download the files
%.gz:
	wget https://datasets.imdbws.com/$@


principals.parquet: title.principals.tsv.gz
	duckdb <<- "EOF"
		copy (
			SELECT 
				tconst, ordering, nconst, category, job,
				str_split(characters,',') as characters
			FROM read_csv_auto('title.principals.tsv.gz', delim='\t', quote='',header=True)
		) to 'principals.parquet' (FORMAT 'parquet', CODEC 'ZSTD') 
	EOF

titles.parquet: title.crew.tsv.gz title.ratings.tsv.gz title.basics.tsv.gz
	duckdb <<- "EOF"
	copy (
		with 
		crew as (
			select 
				tconst,
				{ 'directors': str_split(directors,',')  ,
					'writers' : str_split(writers,',')
				} as crew
			from read_csv_auto('title.crew.tsv.gz', delim='\t', quote='',header=True)
		),
		ratings as (
			SELECT tconst, ROW(averageRating, numVotes) as ratings
			FROM read_csv_auto('title.ratings.tsv.gz', delim='\t', quote='',header=True)
		),
		titles as (
			select * 
				REPLACE (
					str_split(genres,',') as genres,
					case WHEN regexp_matches(startYear,'[0-9]+') THEN CAST(startYear as integer) END as startYear,
					case WHEN regexp_matches(endYear,'[0-9]+') THEN CAST(endYear as integer) END as endYear,
					case WHEN regexp_matches(runtimeMinutes,'[0-9]+') THEN CAST(runtimeMinutes as integer) END as runtimeMinutes,
				),
				crew.crew,
				ratings.ratings,
			FROM read_csv_auto('title.basics.tsv.gz', delim='\t', quote='',header=True, all_varchar=true) as title
			LEFT JOIN crew on title.tconst = crew.tconst
			LEFT JOIN ratings on title.tconst = ratings.tconst 
		)
		select * from titles
	) to 'titles.parquet' (FORMAT 'parquet', CODEC 'ZSTD') 
	EOF

names.parquet: name.basics.tsv.gz
	duckdb <<- "EOF"
	copy (
		SELECT 
			*
		FROM read_csv_auto('name.basics.tsv.gz', delim='\t', quote='',header=True, all_varchar=true) as names
	) to 'names.parquet' (FORMAT 'parquet', CODEC 'ZSTD') 
	EOF