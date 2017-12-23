# Copyright 2017 Google LLC. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def compile_grm(src=None, out=None, data=[]):
  """Compile a Thrax grm file to a FAR file."""
  # Rather than invoking the Thrax compiler directly in a genrule, we go via an
  # intermediate sh_binary. The reason for this is that, unlike a genrule, an
  # sh_binary as a runfiles directory in which all runtime dependencies are
  # present as symlinks in a predictable directory layout. This allows the Thrax
  # compiler to read additional runtime data (e.g. symbol tables) from
  # predictable relative paths, regardless of whether they were present in the
  # source tree or generated by build rules.
  suffix = ".grm"
  if src.endswith(suffix):
    name = src[:-len(suffix)]
  else:
    name = src
  if not name:
    fail("Ill-formed src name: " + src)
  if not out:
    out = name + ".far"
  genrule_name = "compile_%s_grm" % name
  tool_name = genrule_name + "_helper"
  native.sh_binary(
      name = tool_name,
      srcs = ["//mul_034:compile_grm_helper.sh"],
      data = data + [
          src,
          "@thrax//:thraxcompiler",
      ],
  )
  native.genrule(
      name = genrule_name,
      srcs = [src],
      outs = [out],
      cmd = "$(location %s) $< $@" % tool_name,
      tools = [tool_name],
  )

def script_test(script):
  native.sh_test(
      name = "%s_test" % script,
      timeout = "short",
      srcs = ["//utils:eval.sh"],
      args = [
          """
          grep '^[^#]' $(location %s_test.tsv) |
          cut -f 1 |
          $(location //utils:thrax_g2p) \
          --far=$(location %s.far) \
          --far_g2p_key=CODEPOINTS_TO_GRAPHEMES \
          --phoneme_syms=$(location grapheme.syms) |
          diff -B -I '^#' -U0 - $(location %s_test.tsv)
          """ % (script, script, script),
      ],
      data = [
          "%s.far" % script,
          "%s.syms" % script,
          "%s_test.tsv" % script,
          "grapheme.syms",
          "//utils:thrax_g2p",
      ],
  )
