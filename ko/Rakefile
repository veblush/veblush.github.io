
task :post do
  meta = get_metadata(:title, :slug, :categories)
  ['en', 'ko'].each do |lang|
    filename = "#{Time.now.strftime '%Y-%m-%d'}-#{meta[:slug]}.#{lang}.md"
    path = File.join('_posts', filename)
    text = "---
layout: post
title: \"#{meta[:title]}\"
date: #{Time.now.strftime('%Y-%m-%d')}
categories: #{meta[:categories]}
lang: #{lang}
---"
    File.open(path, 'w') { |f| f << text }
  end
end

def get_metadata(*keys)
  meta = {}
  keys.each { |k| meta[k] = ask("#{k.capitalize}: ") }
  meta
end

def ask(qn)
  STDOUT.print qn
  STDIN.gets.chomp
end

