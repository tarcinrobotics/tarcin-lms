/*
 * Copyright (C) 2014 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React from 'react'
import createReactClass from 'create-react-class'
import PropTypes from 'prop-types'
import InputMixin from '../../../mixins/InputMixin'

// eslint-disable-next-line react/prefer-es6-class
export default createReactClass({
  displayName: 'TextInput',

  mixins: [InputMixin],

  propTypes: {
    defaultValue: PropTypes.string,
    renderLabel: PropTypes.string,
    id: PropTypes.string,
    isRequired: PropTypes.bool,
    hintText: PropTypes.string,
    placeholder: PropTypes.string,
    errors: PropTypes.object,
    name: PropTypes.string,
  },

  render() {
    return (
      <div className={this.getClassNames()}>
        {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
        <label>
          {this.props.renderLabel}
          <input
            ref="input"
            type="text"
            defaultValue={this.state.value}
            className="form-control input-block-level"
            placeholder={this.props.placeholder || this.props.renderLabel}
            required={this.props.isRequired ? 'required' : null}
            onChange={this.handleChange}
            aria-invalid={!!this.getErrorMessage()}
            name={this.props.name || null}
          />
          {this.renderHint()}
        </label>
      </div>
    )
  },
})
